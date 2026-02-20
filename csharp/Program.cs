using System.Diagnostics;
using System.Runtime.InteropServices;
using Emgu.CV;
using Emgu.CV.CvEnum;

string imagePath = args.Length > 0 ? args[0] : Path.Combine("..", "images", "lenna.png");
int iterations = args.Length > 1 ? int.Parse(args[1]) : 101;
string? taskFilter = args.Length > 2 ? args[2] : null;

if (!File.Exists(imagePath))
{
    Console.Error.WriteLine($"Image not found: {imagePath}");
    return 1;
}

Mat original = CvInvoke.Imread(imagePath, ImreadModes.Color);
Mat gray = new Mat();
CvInvoke.CvtColor(original, gray, ColorConversion.Bgr2Gray);

string outputDir = Path.Combine("..", "output");
Directory.CreateDirectory(outputDir);

static Mat LeeFilter(Mat src)
{
    int w = src.Cols, h = src.Rows;
    int half = 3;
    byte[] data = new byte[w * h];
    Marshal.Copy(src.DataPointer, data, 0, data.Length);
    byte[] output = new byte[w * h];

    double sumAll = 0, sumSqAll = 0;
    double totalPixels = w * h;
    for (int i = 0; i < data.Length; i++)
    {
        double v = data[i];
        sumAll += v;
        sumSqAll += v * v;
    }
    double overallMean = sumAll / totalPixels;
    double overallVar = sumSqAll / totalPixels - overallMean * overallMean;

    if (overallVar == 0)
    {
        Array.Copy(data, output, data.Length);
    }
    else
    {
        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                double localSum = 0, localSq = 0;
                int count = 0;
                int y0 = Math.Max(y - half, 0);
                int y1 = Math.Min(y + half + 1, h);
                int x0 = Math.Max(x - half, 0);
                int x1 = Math.Min(x + half + 1, w);
                for (int wy = y0; wy < y1; wy++)
                {
                    for (int wx = x0; wx < x1; wx++)
                    {
                        double v = data[wy * w + wx];
                        localSum += v;
                        localSq += v * v;
                        count++;
                    }
                }
                double localMean = localSum / count;
                double localVar = localSq / count - localMean * localMean;
                double weight = localVar / (localVar + overallVar);
                double val = localMean + weight * (data[y * w + x] - localMean);
                output[y * w + x] = (byte)Math.Clamp((int)Math.Round(val), 0, 255);
            }
        }
    }

    Mat result = new Mat(h, w, DepthType.Cv8U, 1);
    Marshal.Copy(output, 0, result.DataPointer, output.Length);
    return result;
}

var benchmarks = new List<BenchmarkDef>
{
    new("invert", "emgucv-invert", src =>
    {
        var dst = new Mat();
        CvInvoke.BitwiseNot(src, dst);
        return dst;
    }, GrayInput: false),

    new("grayscale", "emgucv-grayscale", src =>
    {
        var dst = new Mat();
        CvInvoke.CvtColor(src, dst, ColorConversion.Bgr2Gray);
        return dst;
    }, GrayInput: false),

    new("blur", "emgucv-blur", src =>
    {
        var dst = new Mat();
        CvInvoke.GaussianBlur(src, dst, new System.Drawing.Size(5, 5), 1.0);
        return dst;
    }, GrayInput: false),

    new("edge_detect_sobel", "emgucv-sobel", src =>
    {
        var gx = new Mat();
        var gy = new Mat();
        CvInvoke.Sobel(src, gx, DepthType.Cv64F, 1, 0, 3);
        CvInvoke.Sobel(src, gy, DepthType.Cv64F, 0, 1, 3);
        var gx2 = new Mat();
        var gy2 = new Mat();
        CvInvoke.Multiply(gx, gx, gx2);
        CvInvoke.Multiply(gy, gy, gy2);
        var sumMat = new Mat();
        CvInvoke.Add(gx2, gy2, sumMat);
        var mag = new Mat();
        CvInvoke.Sqrt(sumMat, mag);
        var result = new Mat();
        mag.ConvertTo(result, DepthType.Cv8U);
        return result;
    }, GrayInput: true),

    new("edge_detect_canny", "emgucv-canny", src =>
    {
        var dst = new Mat();
        CvInvoke.Canny(src, dst, 100, 200);
        return dst;
    }, GrayInput: true),

    new("rotate_90", "emgucv-rotate90", src =>
    {
        var dst = new Mat();
        CvInvoke.Rotate(src, dst, RotateFlags.Rotate90Clockwise);
        return dst;
    }, GrayInput: false),

    new("rotate_arbitrary", "emgucv-rotate45", src =>
    {
        int h = src.Rows, w = src.Cols;
        double cx = w / 2.0, cy = h / 2.0;
        double cos45 = Math.Cos(Math.PI / 4);
        double sin45 = Math.Sin(Math.PI / 4);
        int nw = (int)Math.Ceiling(w * cos45 + h * sin45);
        int nh = (int)Math.Ceiling(w * sin45 + h * cos45);
        var M = CvInvoke.GetRotationMatrix2D(
            new System.Drawing.PointF((float)cx, (float)cy), 45, 1.0);
        double[] mdata = new double[6];
        Marshal.Copy(M.DataPointer, mdata, 0, 6);
        mdata[2] += (nw - w) / 2.0;
        mdata[5] += (nh - h) / 2.0;
        Marshal.Copy(mdata, 0, M.DataPointer, 6);
        var dst = new Mat();
        CvInvoke.WarpAffine(src, dst, M, new System.Drawing.Size(nw, nh),
            Inter.Linear);
        return dst;
    }, GrayInput: false),

    new("lee_filter", "csharp-lee", LeeFilter, GrayInput: true),
};

if (taskFilter != null)
    benchmarks = benchmarks.Where(b => b.Task == taskFilter).ToList();

string header = $"{"task",-20} {"slug",-25} {"mean",12} {"median",12} {"std_dev",12} {"min",12} {"max",12} {"total",12}";
Console.WriteLine(header);
Console.WriteLine(new string('-', header.Length));

foreach (var bench in benchmarks)
{
    Mat input = bench.GrayInput ? gray : original;
    var times = new List<double>(iterations);
    Mat? resultImg = null;

    for (int i = 0; i < iterations; i++)
    {
        var sw = Stopwatch.StartNew();
        resultImg = bench.Fn(input);
        sw.Stop();
        times.Add(sw.Elapsed.TotalSeconds);
    }

    resultImg?.Save(Path.Combine(outputDir, $"{bench.Slug}.png"));

    times.Sort();
    double mean = times.Average();
    double median = times[times.Count / 2];
    double total = times.Sum();
    double min = times.Min();
    double max = times.Max();
    double stdDev = times.Count > 1
        ? Math.Sqrt(times.Sum(t => (t - mean) * (t - mean)) / (times.Count - 1))
        : 0.0;

    Console.WriteLine(
        $"{bench.Task,-20} {bench.Slug,-25} {mean,12:F6} {median,12:F6} {stdDev,12:F6} {min,12:F6} {max,12:F6} {total,12:F6}");
}

return 0;

record BenchmarkDef(string Task, string Slug, Func<Mat, Mat> Fn, bool GrayInput);
