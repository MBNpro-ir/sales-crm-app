using System.Diagnostics;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Security.Cryptography;

static class Program
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBox(nint hWnd, string text, string caption, uint type);

    [STAThread]
    public static async Task<int> Main(string[] args)
    {
        try
        {
            var options = ParseArguments(args);
            if (!options.TryGetValue("pid", out var pidText) ||
                !options.TryGetValue("url", out var packageUrl) ||
                !options.TryGetValue("sha256", out var expectedHash) ||
                !options.TryGetValue("target", out var targetDirectory) ||
                !options.TryGetValue("relaunch", out var relaunch))
            {
                throw new InvalidOperationException("پارامترهای به‌روزرسانی کامل نیستند.");
            }

            if (int.TryParse(pidText, out var processId))
            {
                try
                {
                    using var process = Process.GetProcessById(processId);
                    await process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(60));
                }
                catch (ArgumentException)
                {
                    // The CRM has already closed, which is the normal case.
                }
            }

            var work = Path.Combine(Path.GetTempPath(), "SalesCrmUpdater", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(work);
            var zipPath = Path.Combine(work, "package.zip");
            using (var client = new HttpClient())
            using (var source = await client.GetStreamAsync(packageUrl))
            using (var target = File.Create(zipPath))
            {
                await source.CopyToAsync(target);
            }

            var hash = Convert.ToHexString(await SHA256.HashDataAsync(File.OpenRead(zipPath))).ToLowerInvariant();
            if (!string.Equals(hash, expectedHash.Trim().ToLowerInvariant(), StringComparison.Ordinal))
            {
                throw new InvalidDataException("صحت بستهٔ دریافت‌شده تأیید نشد؛ به‌روزرسانی انجام نشد.");
            }

            var staging = Path.Combine(work, "staging");
            ZipFile.ExtractToDirectory(zipPath, staging, true);
            CopyDirectory(staging, targetDirectory);

            Process.Start(new ProcessStartInfo
            {
                FileName = relaunch,
                WorkingDirectory = Path.GetDirectoryName(relaunch) ?? targetDirectory,
                UseShellExecute = true,
            });
            TryDelete(work);
            return 0;
        }
        catch (Exception error)
        {
            MessageBox(0, error.Message, "به‌روزرسان فروش‌یار CRM", 0x10);
            return 1;
        }
    }

    private static Dictionary<string, string> ParseArguments(string[] args)
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (var index = 0; index + 1 < args.Length; index += 2)
        {
            if (args[index].StartsWith("--", StringComparison.Ordinal))
            {
                values[args[index][2..]] = args[index + 1];
            }
        }
        return values;
    }

    private static void CopyDirectory(string source, string target)
    {
        Directory.CreateDirectory(target);
        foreach (var directory in Directory.GetDirectories(source, "*", SearchOption.AllDirectories))
        {
            Directory.CreateDirectory(Path.Combine(target, Path.GetRelativePath(source, directory)));
        }
        foreach (var file in Directory.GetFiles(source, "*", SearchOption.AllDirectories))
        {
            var destination = Path.Combine(target, Path.GetRelativePath(source, file));
            Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
            File.Copy(file, destination, true);
        }
    }

    private static void TryDelete(string directory)
    {
        try { Directory.Delete(directory, true); } catch { /* temporary cleanup is best effort */ }
    }
}
