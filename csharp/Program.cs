using System.Diagnostics;
using Emgu.CV;
using Emgu.CV.Structure;

string imagePath = args.Length > 0 ? args[0] : Path.Combine("..", "images", "lenna.png");
int iterations = args.Length > 1 ? int.Parse(args[1]) : 101;

if (!File.Exists(imagePath))
{
    Console.Error.WriteLine($"Image not found: {imagePath}");
    return 1;
}

Image<Rgb, byte> original = new(imagePath);

var times = new List<double>(iterations);
Image<Rgb, byte>? resultImg = null;

for (int i = 0; i < iterations; i++)
{
    var img = original.Copy();
    var sw = Stopwatch.StartNew();
    resultImg = img.Not();
    sw.Stop();
    times.Add(sw.Elapsed.TotalSeconds);
}

string outputDir = Path.Combine("..", "output");
Directory.CreateDirectory(outputDir);
resultImg?.Save(Path.Combine(outputDir, "emgucv-invert.png"));

times.Sort();
double mean = times.Average();
double median = times[times.Count / 2];
double total = times.Sum();
double min = times.Min();
double max = times.Max();
double stdDev = times.Count > 1
    ? Math.Sqrt(times.Sum(t => (t - mean) * (t - mean)) / (times.Count - 1))
    : 0.0;

string header = $"{"slug",-20} {"mean",12} {"median",12} {"std_dev",12} {"min",12} {"max",12} {"total",12}";
Console.WriteLine(header);
Console.WriteLine(new string('-', header.Length));
Console.WriteLine($"{"emgucv-invert",-20} {mean,12:F6} {median,12:F6} {stdDev,12:F6} {min,12:F6} {max,12:F6} {total,12:F6}");

return 0;
