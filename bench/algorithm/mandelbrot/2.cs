using System;
using System.Linq;
using System.Runtime.Intrinsics;
using System.Security.Cryptography;
using System.Text;

public class MandelBrot
{
    private static readonly Vector256<double> _threshold = Vector256.Create(4.0);
    public static void Main(string[] args)
    {
        var size = args.Length == 0 ? 200 : int.Parse(args[0]);
        size = (size + 7) / 8 * 8;
        var chunkSize = size / 8;
        var inv = 2.0 / size;
        Console.WriteLine($"P4\n{size} {size}");

        var xloc = new (Vector256<double>, Vector256<double>)[chunkSize];
        Span<double> array = stackalloc double[8];
        for (var i = 0; i < chunkSize; i++)
        {
            var offset = i * 8;
            for (var j = 0; j < 8; j++)
            {
                array[j] = (offset + j) * inv - 1.5;
            }
            xloc[i] = (Vector256.Create((ReadOnlySpan<double>)array.Slice(0, 4)), Vector256.Create((ReadOnlySpan<double>)array.Slice(4, 4)));
        }

        var data = new byte[size * chunkSize];

        for (var y = 0; y < size; y++)
        {
            var ci = y * inv - 1.0;
            for (var x = 0; x < chunkSize; x++)
            {
                var r = mbrot8(xloc[x], ci);
                if (r > 0)
                {
                    data[y * chunkSize + x] = r;
                }
            }
        }

        using var hasher = MD5.Create();
        var hash = hasher.ComputeHash(data);
        Console.WriteLine(ToHexString(hash));
    }

    static byte mbrot8((Vector256<double>, Vector256<double>) cr, double civ)
    {
        var ci = Vector256.Create(civ);
        var zr0 = Vector256<double>.Zero;
        var zr1 = Vector256<double>.Zero;
        var zi0 = Vector256<double>.Zero;
        var zi1 = Vector256<double>.Zero;
        var tr0 = Vector256<double>.Zero;
        var tr1 = Vector256<double>.Zero;
        var ti0 = Vector256<double>.Zero;
        var ti1 = Vector256<double>.Zero;
        var absz0 = Vector256<double>.Zero;
        var absz1 = Vector256<double>.Zero;
        for (var _i = 0; _i < 10; _i++)
        {
            for (var _j = 0; _j < 5; _j++)
            {
                var tmp = (zr0 + zr0) * zi0;
                zi0 = tmp + ci;
                zr0 = tr0 - ti0 + cr.Item1;

                tr0 = zr0 * zr0;
                ti0 = zi0 * zi0;

                tmp = (zr1 + zr1) * zi1;
                zi1 = tmp + ci;
                zr1 = tr1 - ti1 + cr.Item2;

                tr1 = zr1 * zr1;
                ti1 = zi1 * zi1;
            }
            absz0 = tr0 + ti0;
            absz1 = tr1 + ti1;
            if (Vector256.GreaterThanAll(absz0, _threshold) && Vector256.GreaterThanAll(absz1, _threshold))
            {
                return 0;
            }
        }

        var accu = (byte)0;
        for (var i = 0; i < 4; i++)
        {
            if (absz0[i] <= 4.0)
            {
                accu |= (byte)(0x80 >> i);
            }
        }
        for (var i = 4; i < 8; i++)
        {
            if (absz1[i - 4] <= 4.0)
            {
                accu |= (byte)(0x80 >> i);
            }
        }
        return accu;
    }

    static string ToHexString(byte[] ba)
    {
        StringBuilder hex = new StringBuilder(ba.Length * 2);
        foreach (byte b in ba)
        {
            hex.AppendFormat("{0:x2}", b);
        }
        return hex.ToString();
    }
}
