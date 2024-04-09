// See https://aka.ms/new-console-template for more information

using System.ComponentModel;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using Emgu.CV;
using Emgu.CV.Structure;

String path = "images.lenna.png";
UInt16 iterations = 101;
// var test = csharp_images.images.images.lenna;
// Console.WriteLine(test.Length);
Image<Rgb, byte> img = new Emgu.CV.Image<Rgb, Byte>("C:\\Users\\smeal\\repos\\lang-image-benchmark\\csharp_images\\images\\lenna.png");

Stopwatch stopwatch = Stopwatch.StartNew();
for (int i = 0; i < iterations; i++)
{
    var out_image = img.Not();
    // var out_image = img.Mat.GetRawData();
    // foreach (var c in out_image)
    // {
    //      var test = ~c;
    // }
}

stopwatch.Stop();
var time_seconds = stopwatch.Elapsed.TotalSeconds;
Console.WriteLine(time_seconds);

Console.WriteLine(img.Size);
