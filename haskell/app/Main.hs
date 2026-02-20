{-# LANGUAGE BangPatterns #-}
module Main where

import Codec.Picture
import Codec.Picture.Types
import Control.DeepSeq (force)
import Control.Exception (evaluate)
import Control.Monad (forM_)
import Data.List (sort)
import Data.Word (Word8)
import GHC.Clock (getMonotonicTimeNSec)
import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs)
import System.FilePath (takeDirectory, (</>))
import Text.Printf (printf)
import qualified Data.Vector.Storable as V
import qualified Data.Vector.Storable.Mutable as MV
import Control.Monad.ST (runST)

data Stats = Stats
  { statMean   :: !Double
  , statMedian :: !Double
  , statStdDev :: !Double
  , statMin    :: !Double
  , statMax    :: !Double
  , statTotal  :: !Double
  }

computeStats :: [Double] -> Stats
computeStats times =
  let sorted = sort times
      n      = length sorted
      total  = sum sorted
      mean'  = total / fromIntegral n
      median' = sorted !! (n `div` 2)
      mn     = head sorted
      mx     = last sorted
      stdDev = if n > 1
               then sqrt (sum [(t - mean') ** 2 | t <- sorted] / fromIntegral (n - 1))
               else 0.0
  in Stats mean' median' stdDev mn mx total

clamp :: Int -> Int -> Int -> Int
clamp v lo hi = max lo (min hi v)

-- ============================================================
-- Image processing implementations
-- ============================================================

-- Invert: pixelMap
invertPixelMap :: Image PixelRGB8 -> Image PixelRGB8
invertPixelMap = pixelMap (\(PixelRGB8 r g b) -> PixelRGB8 (255 - r) (255 - g) (255 - b))

-- Invert: mutable vector
invertManual :: Image PixelRGB8 -> Image PixelRGB8
invertManual (Image w h dat) =
  let newDat = runST $ do
        mv <- V.thaw dat
        let len = MV.length mv
        let go i
              | i >= len  = return ()
              | otherwise = do
                  v <- MV.read mv i
                  MV.write mv i (255 - v)
                  go (i + 1)
        go 0
        V.freeze mv
  in Image w h newDat

-- Grayscale: RGB to single channel
grayscaleConvert :: Image PixelRGB8 -> Image Pixel8
grayscaleConvert = pixelMap (\(PixelRGB8 r g b) ->
  round (0.299 * fromIntegral r + 0.587 * fromIntegral g + 0.114 * fromIntegral b :: Double))

-- Blur: 5x5 Gaussian, sigma=1.0
gaussKernel :: [Double]
gaussKernel =
  [ 0.00297, 0.01331, 0.02194, 0.01331, 0.00297
  , 0.01331, 0.05963, 0.09832, 0.05963, 0.01331
  , 0.02194, 0.09832, 0.16210, 0.09832, 0.02194
  , 0.01331, 0.05963, 0.09832, 0.05963, 0.01331
  , 0.00297, 0.01331, 0.02194, 0.01331, 0.00297
  ]

getChannel :: Int -> PixelRGB8 -> Word8
getChannel 0 (PixelRGB8 r _ _) = r
getChannel 1 (PixelRGB8 _ g _) = g
getChannel _ (PixelRGB8 _ _ b) = b

blur5x5 :: Image PixelRGB8 -> Image PixelRGB8
blur5x5 img@(Image w h _) = generateImage go w h
  where
    go x y = PixelRGB8 (ch 0) (ch 1) (ch 2)
      where
        ch c = let s = sum [ (gaussKernel !! ((ky + 2) * 5 + (kx + 2)))
                             * fromIntegral (getChannel c (pixelAt img
                                 (clamp (x + kx) 0 (w - 1))
                                 (clamp (y + ky) 0 (h - 1))))
                           | ky <- [-2..2], kx <- [-2..2] ] :: Double
               in round s

-- Sobel edge detection on grayscale
sobelEdge :: Image Pixel8 -> Image Pixel8
sobelEdge img@(Image w h _) = generateImage go w h
  where
    gxK = [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]] :: [[Double]]
    gyK = [[-1, -2, -1], [0, 0, 0], [1, 2, 1]] :: [[Double]]
    go x y =
      let gx = sum [ fromIntegral (pixelAt img (clamp (x + kx) 0 (w - 1))
                                               (clamp (y + ky) 0 (h - 1)))
                     * ((gxK !! (ky + 1)) !! (kx + 1))
                   | ky <- [-1..1], kx <- [-1..1] ] :: Double
          gy = sum [ fromIntegral (pixelAt img (clamp (x + kx) 0 (w - 1))
                                               (clamp (y + ky) 0 (h - 1)))
                     * ((gyK !! (ky + 1)) !! (kx + 1))
                   | ky <- [-1..1], kx <- [-1..1] ] :: Double
          mag = sqrt (gx * gx + gy * gy)
      in round (min 255 mag) :: Word8

-- Rotate 90 clockwise
rotate90CW :: Image PixelRGB8 -> Image PixelRGB8
rotate90CW img@(Image w h _) = generateImage go h w
  where
    go ox oy = pixelAt img oy (h - 1 - ox)

-- Rotate 45 degrees with bilinear interpolation, expanded canvas
rotate45Bilinear :: Image PixelRGB8 -> Image PixelRGB8
rotate45Bilinear img@(Image w h _) = generateImage go nw nh
  where
    angle = pi / 4.0 :: Double
    cosA = cos angle
    sinA = sin angle
    nw = ceiling (fromIntegral w * cosA + fromIntegral h * sinA) :: Int
    nh = ceiling (fromIntegral w * sinA + fromIntegral h * cosA) :: Int
    cx = fromIntegral w / 2.0 :: Double
    cy = fromIntegral h / 2.0
    ncx = fromIntegral nw / 2.0
    ncy = fromIntegral nh / 2.0

    go ox oy =
      let dx = fromIntegral ox - ncx
          dy = fromIntegral oy - ncy
          sx = dx * cosA + dy * sinA + cx
          sy = (-dx) * sinA + dy * cosA + cy
          wf = fromIntegral w :: Double
          hf = fromIntegral h :: Double
      in if sx >= 0 && sx < wf - 1 && sy >= 0 && sy < hf - 1
         then bilinear sx sy
         else PixelRGB8 0 0 0

    bilinear sx sy =
      let x0 = floor sx :: Int
          y0 = floor sy :: Int
          fx = sx - fromIntegral x0 :: Double
          fy = sy - fromIntegral y0
          p00 = pixelAt img x0 y0
          p10 = pixelAt img (x0 + 1) y0
          p01 = pixelAt img x0 (y0 + 1)
          p11 = pixelAt img (x0 + 1) (y0 + 1)
          interp c = let v = (1 - fx) * (1 - fy) * fromIntegral (getChannel c p00)
                           + fx * (1 - fy) * fromIntegral (getChannel c p10)
                           + (1 - fx) * fy * fromIntegral (getChannel c p01)
                           + fx * fy * fromIntegral (getChannel c p11) :: Double
                     in round v
      in PixelRGB8 (interp 0) (interp 1) (interp 2)

-- Lee filter on grayscale (7x7 window)
leeFilter7 :: Image Pixel8 -> Image Pixel8
leeFilter7 img@(Image w h _) =
  let dat = imageData img
      totalPixels = fromIntegral (V.length dat) :: Double
      (!sumAll, !sumSqAll) = V.foldl' (\(!s, !sq) wv ->
        let v = fromIntegral wv :: Double
        in (s + v, sq + v * v)) (0.0, 0.0) dat
      overallMean = sumAll / totalPixels
      overallVar = sumSqAll / totalPixels - overallMean * overallMean
  in if overallVar == 0
     then img
     else generateImage (go overallVar) w h
  where
    half = 3 :: Int
    go ovar x y =
      let y0 = max 0 (y - half)
          y1 = min h (y + half + 1)
          x0 = max 0 (x - half)
          x1 = min w (x + half + 1)
          (!lsum, !lsq, !cnt) = foldWindow x0 x1 y0 y1
          localMean = lsum / cnt
          localVar = lsq / cnt - localMean * localMean
          weight = localVar / (localVar + ovar)
          val = localMean + weight * (fromIntegral (pixelAt img x y) - localMean)
      in round (max 0 (min 255 val)) :: Word8

    foldWindow x0 x1 y0 y1 = go' y0 0.0 0.0 0.0
      where
        go' !wy !s !sq !c
          | wy >= y1 = (s, sq, c)
          | otherwise = goX x0 wy s sq c
        goX !wx !wy !s !sq !c
          | wx >= x1 = go' (wy + 1) s sq c
          | otherwise =
              let v = fromIntegral (pixelAt img wx wy) :: Double
              in goX (wx + 1) wy (s + v) (sq + v * v) (c + 1)

-- ============================================================
-- Benchmark runners
-- ============================================================

getTimeSec :: IO Double
getTimeSec = do
  ns <- getMonotonicTimeNSec
  return (fromIntegral ns / 1e9)

copyImageRgb :: Image PixelRGB8 -> IO (Image PixelRGB8)
copyImageRgb (Image w h dat) = do
  let !copy = V.force dat
  !i <- evaluate (force (Image w h copy))
  return i

copyImageGray :: Image Pixel8 -> IO (Image Pixel8)
copyImageGray (Image w h dat) = do
  let !copy = V.force dat
  !i <- evaluate (force (Image w h copy))
  return i

runBenchRgb :: String -> (Image PixelRGB8 -> Image PixelRGB8) -> Image PixelRGB8 -> Int -> FilePath -> IO Stats
runBenchRgb slug fn original iterations outputDir = do
  times <- mapM (\_ -> do
    img' <- copyImageRgb original
    start <- getTimeSec
    !result <- evaluate (force (fn img'))
    end <- getTimeSec
    let !elapsed = end - start
    return (elapsed, result)
    ) [1..iterations]
  let lastResult = snd (last times)
  savePngImage (outputDir </> (slug ++ ".png")) (ImageRGB8 lastResult)
  return $ computeStats (map fst times)

runBenchRgbToGray :: String -> (Image PixelRGB8 -> Image Pixel8) -> Image PixelRGB8 -> Int -> FilePath -> IO Stats
runBenchRgbToGray slug fn original iterations outputDir = do
  times <- mapM (\_ -> do
    img' <- copyImageRgb original
    start <- getTimeSec
    !result <- evaluate (force (fn img'))
    end <- getTimeSec
    let !elapsed = end - start
    return (elapsed, result)
    ) [1..iterations]
  let lastResult = snd (last times)
  savePngImage (outputDir </> (slug ++ ".png")) (ImageY8 lastResult)
  return $ computeStats (map fst times)

runBenchGray :: String -> (Image Pixel8 -> Image Pixel8) -> Image Pixel8 -> Int -> FilePath -> IO Stats
runBenchGray slug fn original iterations outputDir = do
  times <- mapM (\_ -> do
    img' <- copyImageGray original
    start <- getTimeSec
    !result <- evaluate (force (fn img'))
    end <- getTimeSec
    let !elapsed = end - start
    return (elapsed, result)
    ) [1..iterations]
  let lastResult = snd (last times)
  savePngImage (outputDir </> (slug ++ ".png")) (ImageY8 lastResult)
  return $ computeStats (map fst times)

-- ============================================================
-- Main
-- ============================================================

main :: IO ()
main = do
  args <- getArgs
  let imagePath  = if not (null args) then head args else "../images/lenna.png"
      iterations = if length args > 1 then read (args !! 1) else 101
      taskFilter = if length args > 2 then Just (args !! 2) else Nothing

  result <- readPng imagePath
  case result of
    Left err -> putStrLn ("Failed to load image: " ++ err)
    Right dynImg -> do
      let img = convertRGB8 dynImg

      -- Pre-compute grayscale (outside timing)
      let grayImg = pixelMap (\(PixelRGB8 r g b) ->
            round (0.299 * fromIntegral r + 0.587 * fromIntegral g
                   + 0.114 * fromIntegral b :: Double) :: Word8) img

      let imgDir = takeDirectory imagePath
          outputDir = imgDir </> ".." </> "output"
      createDirectoryIfMissing True outputDir

      let rgbBenches =
            [ ("invert",           "juicypixels-invert", invertPixelMap)
            , ("invert",           "haskell-manual",     invertManual)
            , ("blur",             "haskell-blur",       blur5x5)
            , ("rotate_90",        "haskell-rotate90",   rotate90CW)
            , ("rotate_arbitrary", "haskell-rotate45",   rotate45Bilinear)
            ]

      let rgbToGrayBenches =
            [ ("grayscale", "haskell-grayscale", grayscaleConvert)
            ]

      let grayBenches =
            [ ("edge_detect_sobel", "haskell-sobel", sobelEdge)
            , ("lee_filter",        "haskell-lee",   leeFilter7)
            ]

      let filterTask Nothing xs  = xs
          filterTask (Just t) xs = filter (\(task, _, _) -> task == t) xs

      let rgbBenches'       = filterTask taskFilter rgbBenches
          rgbToGrayBenches' = filterTask taskFilter rgbToGrayBenches
          grayBenches'      = filterTask taskFilter grayBenches

      let header = printf "%-20s %-25s %12s %12s %12s %12s %12s %12s"
                     ("task" :: String) ("slug" :: String) ("mean" :: String)
                     ("median" :: String) ("std_dev" :: String)
                     ("min" :: String) ("max" :: String)
                     ("total" :: String) :: String
      putStrLn header
      putStrLn (replicate (length header) '-')

      forM_ rgbBenches' $ \(task, slug, fn) -> do
        stats <- runBenchRgb slug fn img iterations outputDir
        printf "%-20s %-25s %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f\n"
          (task :: String) (slug :: String) (statMean stats) (statMedian stats)
          (statStdDev stats) (statMin stats) (statMax stats) (statTotal stats)

      forM_ rgbToGrayBenches' $ \(task, slug, fn) -> do
        stats <- runBenchRgbToGray slug fn img iterations outputDir
        printf "%-20s %-25s %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f\n"
          (task :: String) (slug :: String) (statMean stats) (statMedian stats)
          (statStdDev stats) (statMin stats) (statMax stats) (statTotal stats)

      forM_ grayBenches' $ \(task, slug, fn) -> do
        stats <- runBenchGray slug fn grayImg iterations outputDir
        printf "%-20s %-25s %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f\n"
          (task :: String) (slug :: String) (statMean stats) (statMedian stats)
          (statStdDev stats) (statMin stats) (statMax stats) (statTotal stats)
