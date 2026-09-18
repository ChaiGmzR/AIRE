using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

internal static class Program
{
    private const string InstalledExecutable = "pcb_boxing_system.exe";
    private const string UpdateMarker = "update.lock";
    private const string UninstallMarker = "uninstall.lock";

    [STAThread]
    private static void Main()
    {
        using var singleInstance = new Mutex(true, "IlsanPackingSystem.Watchdog", out var isOwner);
        if (!isOwner)
        {
            return;
        }

        var installDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "IlsanPackingSystem");
        var executablePath = Path.Combine(installDirectory, InstalledExecutable);
        var updateMarkerPath = Path.Combine(installDirectory, UpdateMarker);
        var uninstallMarkerPath = Path.Combine(installDirectory, UninstallMarker);

        while (!File.Exists(uninstallMarkerPath))
        {
            if (File.Exists(updateMarkerPath))
            {
                Thread.Sleep(1000);
                continue;
            }

            if (!File.Exists(executablePath))
            {
                Thread.Sleep(2000);
                continue;
            }

            try
            {
                using var app = Process.Start(new ProcessStartInfo
                {
                    FileName = executablePath,
                    WorkingDirectory = installDirectory,
                    UseShellExecute = true,
                });

                if (app is null)
                {
                    Thread.Sleep(2000);
                    continue;
                }

                app.WaitForExit();
            }
            catch
            {
                Thread.Sleep(2000);
            }

            if (!File.Exists(updateMarkerPath) && !File.Exists(uninstallMarkerPath))
            {
                Thread.Sleep(2000);
            }
        }
    }
}
