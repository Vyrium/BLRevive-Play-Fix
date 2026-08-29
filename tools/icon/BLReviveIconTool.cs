using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

[assembly: System.Reflection.AssemblyTitle("BLRevive Icon Tool")]
[assembly: System.Reflection.AssemblyDescription("Builds the BLRevive multi-resolution Windows icon")]
[assembly: System.Reflection.AssemblyCompany("BLRevive Community")]
[assembly: System.Reflection.AssemblyProduct("BLRevive Steam Play Fix")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("1.0.0.0")]

internal static class Program
{
    private static readonly int[] IconSizes = { 256, 128, 96, 64, 48, 32, 24, 16 };

    private sealed class IconFrame
    {
        public byte Width;
        public byte Height;
        public byte[] Data;
    }

    private static int Main(string[] args)
    {
        try
        {
            string input = null;
            string output = null;

            for (int i = 0; i < args.Length; i++)
            {
                if (String.Equals(args[i], "--input", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                    input = args[++i];
                else if (String.Equals(args[i], "--output", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                    output = args[++i];
            }

            if (String.IsNullOrWhiteSpace(input) || String.IsNullOrWhiteSpace(output))
            {
                Console.Error.WriteLine("Usage: BLReviveIconTool.exe --input <png> --output <ico>");
                return 2;
            }

            if (!File.Exists(input))
                throw new FileNotFoundException("Input logo was not found.", input);

            List<IconFrame> frames;
            using (Image logo = Image.FromFile(input, true))
            {
                if (logo.Width <= 0 || logo.Height <= 0)
                    throw new InvalidDataException("Input logo has invalid dimensions.");

                frames = BuildFrames(logo);
            }

            WriteIco(output, frames);

            Console.WriteLine("Built BLRevive icon with {0} frame(s).", frames.Count);
            Console.WriteLine("Source: {0}", input);
            Console.WriteLine("Output: {0}", output);
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("ERROR: " + ex.Message);
            Console.Error.WriteLine(ex.ToString());
            return 1;
        }
    }

    private static List<IconFrame> BuildFrames(Image logo)
    {
        List<IconFrame> frames = new List<IconFrame>();
        foreach (int size in IconSizes)
        {
            using (Bitmap bitmap = ResizeLogo(logo, size))
            using (MemoryStream png = new MemoryStream())
            {
                bitmap.Save(png, ImageFormat.Png);

                IconFrame frame = new IconFrame();
                frame.Width = DimensionByte(size);
                frame.Height = DimensionByte(size);
                frame.Data = png.ToArray();
                frames.Add(frame);
            }
        }
        return frames;
    }

    private static Bitmap ResizeLogo(Image source, int size)
    {
        Bitmap output = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (Graphics graphics = Graphics.FromImage(output))
        using (ImageAttributes attributes = new ImageAttributes())
        {
            graphics.Clear(Color.Transparent);
            graphics.CompositingMode = CompositingMode.SourceCopy;
            graphics.CompositingQuality = CompositingQuality.HighQuality;
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.SmoothingMode = SmoothingMode.HighQuality;
            attributes.SetWrapMode(WrapMode.TileFlipXY);

            double scale = Math.Min((double)size / source.Width, (double)size / source.Height);
            int width = Math.Max(1, (int)Math.Round(source.Width * scale));
            int height = Math.Max(1, (int)Math.Round(source.Height * scale));
            int x = (size - width) / 2;
            int y = (size - height) / 2;

            graphics.DrawImage(
                source,
                new Rectangle(x, y, width, height),
                0,
                0,
                source.Width,
                source.Height,
                GraphicsUnit.Pixel,
                attributes);
        }
        return output;
    }

    private static byte DimensionByte(int dimension)
    {
        return dimension >= 256 ? (byte)0 : (byte)dimension;
    }

    private static void WriteIco(string outputPath, List<IconFrame> frames)
    {
        using (FileStream stream = new FileStream(outputPath, FileMode.Create, FileAccess.Write, FileShare.None))
        using (BinaryWriter writer = new BinaryWriter(stream))
        {
            writer.Write((ushort)0);
            writer.Write((ushort)1);
            writer.Write((ushort)frames.Count);

            uint offset = checked((uint)(6 + frames.Count * 16));
            foreach (IconFrame frame in frames)
            {
                writer.Write(frame.Width);
                writer.Write(frame.Height);
                writer.Write((byte)0);
                writer.Write((byte)0);
                writer.Write((ushort)1);
                writer.Write((ushort)32);
                writer.Write(checked((uint)frame.Data.Length));
                writer.Write(offset);
                offset = checked(offset + (uint)frame.Data.Length);
            }

            foreach (IconFrame frame in frames)
                writer.Write(frame.Data);
        }
    }
}
