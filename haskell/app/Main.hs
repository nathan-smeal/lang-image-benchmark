{-# LANGUAGE BangPatterns #-}
module Main where

import Codec.Picture
import Codec.Picture.Types
import Control.DeepSeq (force)
import Control.Exception (evaluate)
import Control.Monad (forM_)
import Control.Monad.ST (runST)
import Data.List (sort)
import Data.Word (Word8)
import GHC.Clock (getMonotonicTimeNSec)
import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs)
import System.FilePath (takeDirectory, (</>))
import Text.Printf (printf)
import qualified Data.Vector.Storable as V
import qualified Data.Vector.Storable.Mutable as MV

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

-- Implementation 1: pixelMap (idiomatic JuicyPixels)
invertPixelMap :: Image PixelRGB8 -> Image PixelRGB8
invertPixelMap = pixelMap (\(PixelRGB8 r g b) -> PixelRGB8 (255 - r) (255 - g) (255 - b))

-- Implementation 2: mutable STVector in-place byte inversion
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

getTimeSec :: IO Double
getTimeSec = do
  ns <- getMonotonicTimeNSec
  return (fromIntegral ns / 1e9)

copyImage :: Image PixelRGB8 -> IO (Image PixelRGB8)
copyImage (Image w h dat) = do
  let !copy = V.force dat  -- create a fresh copy of the vector
  !img <- evaluate (force (Image w h copy))
  return img

runBench :: String -> (Image PixelRGB8 -> Image PixelRGB8) -> Image PixelRGB8 -> Int -> FilePath -> IO Stats
runBench slug fn original iterations outputDir = do
  times <- mapM (\_ -> do
    img <- copyImage original
    start <- getTimeSec
    !result <- evaluate (force (fn img))
    end <- getTimeSec
    let !elapsed = end - start
    return (elapsed, result)
    ) [1..iterations]

  let lastResult = snd (last times)
  let outPath = outputDir </> (slug ++ ".png")
  savePngImage outPath (ImageRGB8 lastResult)

  return $ computeStats (map fst times)

main :: IO ()
main = do
  args <- getArgs
  let imagePath  = if not (null args) then head args else "../images/lenna.png"
      iterations = if length args > 1 then read (args !! 1) else 101

  result <- readPng imagePath
  case result of
    Left err -> putStrLn ("Failed to load image: " ++ err)
    Right dynImg -> do
      let img = convertRGB8 dynImg

      let imgDir = takeDirectory imagePath
          outputDir = imgDir </> ".." </> "output"
      createDirectoryIfMissing True outputDir

      let benchmarks = [ ("juicypixels-invert", invertPixelMap)
                       , ("haskell-manual",     invertManual)
                       ]

      let header = printf "%-20s %12s %12s %12s %12s %12s %12s"
                     ("slug" :: String) ("mean" :: String) ("median" :: String)
                     ("std_dev" :: String) ("min" :: String) ("max" :: String)
                     ("total" :: String) :: String
      putStrLn header
      putStrLn (replicate (length header) '-')

      forM_ benchmarks $ \(slug, fn) -> do
        stats <- runBench slug fn img iterations outputDir
        printf "%-20s %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f\n"
          (slug :: String) (statMean stats) (statMedian stats) (statStdDev stats)
          (statMin stats) (statMax stats) (statTotal stats)
