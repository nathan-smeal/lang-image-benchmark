// See https://aka.ms/new-console-template for more information
using System.Runtime.InteropServices;
using Emgu.CV;
Console.WriteLine("Hello, World!");


Mat img = CvInvoke.Imread("./images/lenna.png", Emgu.CV.CvEnum.ImreadModes.AnyColor);

Console.WriteLine(img.Dims);