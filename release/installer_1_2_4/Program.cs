using System;
using Microsoft.Win32;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;

internal static class Program
{
    private const string ProductName = "AIRE ISEMM";
    private const string DisplayVersion = "1.2.4";
    private const string ArchiveResource = "AIRE_1.2.4_windows.zip";
    private const string InstalledExecutable = "pcb_boxing_system.exe";
    private const string UninstallerExecutable = "AIRE_Uninstall.exe";
    private const string WatchdogExecutable = "AIRE_Watchdog.exe";

    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Any(argument => string.Equals(argument, "--update", StringComparison.OrdinalIgnoreCase)))
        {
            try
            {
                InstallerCore.Install(null);
                return 0;
            }
            catch (Exception error)
            {
                ShowMessage($"No se pudo actualizar AIRE 1.2.4.\n\n{error.Message}", "AIRE 1.2.4");
                return 1;
            }
        }

        if (args.Any(argument => string.Equals(argument, "--uninstall", StringComparison.OrdinalIgnoreCase)))
        {
            try
            {
                InstallerCore.Uninstall();
                return 0;
            }
            catch (Exception error)
            {
                ShowMessage($"No se pudo desinstalar AIRE.\n\n{error.Message}", "AIRE");
                return 1;
            }
        }

        ApplicationConfiguration.Initialize();
        Application.Run(new InstallerForm());
        return 0;
    }

    private static void ShowMessage(string text, string caption)
    {
        MessageBox.Show(text, caption, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }

    private sealed class InstallerForm : Form
    {
        private readonly Button installButton;
        private readonly Button cancelButton;
        private readonly ProgressBar progressBar;
        private readonly Label statusLabel;
        private bool installing;

        public InstallerForm()
        {
            Text = $"AIRE {DisplayVersion} - Instalador";
            ClientSize = new Size(560, 330);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);

            var title = new Label
            {
                AutoSize = true,
                Font = new Font(Font.FontFamily, 18, FontStyle.Bold),
                Location = new Point(32, 28),
                Text = "Aplicación Integrada al Registro de Empaque",
            };
            var description = new Label
            {
                AutoSize = false,
                Location = new Point(35, 75),
                Size = new Size(490, 48),
                Text = "AIRE se instalara en este equipo.\nLa aplicación integra el proceso LG-PWS ademas de otras verificaciones de calidad.",
            };
            var version = new Label
            {
                AutoSize = true,
                ForeColor = Color.DimGray,
                Location = new Point(35, 137),
                Text = $"Version {DisplayVersion}",
            };
            var installPath = new Label
            {
                AutoSize = true,
                Location = new Point(35, 178),
                Text = "Ubicacion:",
            };
            var pathTextBox = new TextBox
            {
                Location = new Point(35, 200),
                ReadOnly = true,
                Size = new Size(490, 23),
                Text = InstallerCore.InstallDirectory,
            };
            progressBar = new ProgressBar
            {
                Location = new Point(35, 242),
                Size = new Size(490, 22),
                Style = ProgressBarStyle.Marquee,
                Visible = false,
            };
            statusLabel = new Label
            {
                AutoSize = true,
                ForeColor = Color.DimGray,
                Location = new Point(35, 270),
                Text = "Listo para instalar.",
            };
            installButton = new Button
            {
                Anchor = AnchorStyles.Bottom | AnchorStyles.Right,
                Location = new Point(425, 294),
                Size = new Size(100, 28),
                Text = "Instalar",
            };
            cancelButton = new Button
            {
                Anchor = AnchorStyles.Bottom | AnchorStyles.Right,
                Location = new Point(315, 294),
                Size = new Size(100, 28),
                Text = "Cancelar",
            };

            installButton.Click += async (_, _) => await InstallAsync();
            cancelButton.Click += (_, _) => Close();
            Controls.AddRange(new Control[]
            {
                title, description, version, installPath, pathTextBox,
                progressBar, statusLabel, installButton, cancelButton,
            });
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (installing)
            {
                e.Cancel = true;
                return;
            }

            base.OnFormClosing(e);
        }

        private async Task InstallAsync()
        {
            installing = true;
            installButton.Enabled = false;
            cancelButton.Enabled = false;
            progressBar.Visible = true;
            try
            {
                await Task.Run(() => InstallerCore.Install(message =>
                    BeginInvoke(() => statusLabel.Text = message)));
                statusLabel.Text = "Instalacion completada. Iniciando AIRE...";
                await Task.Delay(500);
                installing = false;
                Close();
            }
            catch (Exception error)
            {
                installing = false;
                cancelButton.Enabled = true;
                installButton.Enabled = true;
                progressBar.Visible = false;
                MessageBox.Show(this, $"No se pudo instalar AIRE.\n\n{error.Message}",
                    "AIRE", MessageBoxButtons.OK, MessageBoxIcon.Error);
                statusLabel.Text = "La instalacion no se completo.";
            }
        }
    }

    private static class InstallerCore
    {
        internal static string InstallDirectory => Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "IlsanPackingSystem");

        private static string InstalledPath => Path.Combine(InstallDirectory, InstalledExecutable);
        private static string UninstallerPath => Path.Combine(InstallDirectory, UninstallerExecutable);
        private static string WatchdogPath => Path.Combine(InstallDirectory, WatchdogExecutable);
        private static string UpdateMarkerPath => Path.Combine(InstallDirectory, "update.lock");
        private static string UninstallMarkerPath => Path.Combine(InstallDirectory, "uninstall.lock");
        private static string UninstallKeyPath =>
            "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\IlsanPackingSystem";
        private const string StartupKeyPath =
            "Software\\Microsoft\\Windows\\CurrentVersion\\Run";
        private const string StartupValueName = "IlsanPackingSystem";

        internal static void Install(Action<string>? report)
        {
            Directory.CreateDirectory(InstallDirectory);
            File.WriteAllText(UpdateMarkerPath, DateTime.UtcNow.ToString("O"));
            try
            {
                StopInstalledApp();
                report?.Invoke("Copiando archivos de AIRE...");
                ExtractApplication(report);
                report?.Invoke("Registrando AIRE en Windows...");
                File.Copy(Environment.ProcessPath!, UninstallerPath, true);
                CreateShortcuts();
                RegisterUninstall();
                RegisterStartup();
                report?.Invoke("Iniciando supervision de AIRE...");
                StartWatchdog();
                File.Delete(UpdateMarkerPath);
            }
            catch
            {
                TryDelete(UpdateMarkerPath);
                throw;
            }
        }

        internal static void Uninstall()
        {
            Directory.CreateDirectory(InstallDirectory);
            File.WriteAllText(UninstallMarkerPath, DateTime.UtcNow.ToString("O"));
            RemoveStartup();
            StopInstalledApp();
            StopWatchdog();
            RemoveShortcuts();
            Registry.CurrentUser.DeleteSubKeyTree(UninstallKeyPath, throwOnMissingSubKey: false);

            var cleanupCommand = $"ping 127.0.0.1 -n 3 > nul && rmdir /s /q \"{InstallDirectory}\"";
            Process.Start(new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = $"/d /c \"{cleanupCommand}\"",
                CreateNoWindow = true,
                UseShellExecute = false,
                WindowStyle = ProcessWindowStyle.Hidden,
            });
        }

        private static void StartWatchdog()
        {
            if (!File.Exists(WatchdogPath))
            {
                throw new InvalidOperationException("No se encontro el supervisor de AIRE.");
            }

            Process.Start(new ProcessStartInfo
            {
                FileName = WatchdogPath,
                WorkingDirectory = InstallDirectory,
                UseShellExecute = true,
            });
        }

        private static void RegisterStartup()
        {
            using var key = Registry.CurrentUser.CreateSubKey(StartupKeyPath);
            if (key is null)
            {
                throw new InvalidOperationException("No se pudo configurar el inicio automatico de AIRE.");
            }

            key.SetValue(StartupValueName, $"\"{WatchdogPath}\"");
        }

        private static void RemoveStartup()
        {
            using var key = Registry.CurrentUser.OpenSubKey(StartupKeyPath, writable: true);
            key?.DeleteValue(StartupValueName, throwOnMissingValue: false);
        }

        private static void StopWatchdog()
        {
            foreach (var process in Process.GetProcessesByName("AIRE_Watchdog"))
            {
                try
                {
                    if (string.Equals(process.MainModule?.FileName, WatchdogPath, StringComparison.OrdinalIgnoreCase))
                    {
                        process.Kill(true);
                        process.WaitForExit(5000);
                    }
                }
                catch
                {
                    // The supervisor may already be stopping.
                }
                finally
                {
                    process.Dispose();
                }
            }
        }

        private static void TryDelete(string path)
        {
            try
            {
                if (File.Exists(path)) File.Delete(path);
            }
            catch
            {
                // The cleanup process will remove the marker if needed.
            }
        }

        private static void ExtractApplication(Action<string>? report)
        {
            using var archiveStream = Assembly.GetExecutingAssembly()
                .GetManifestResourceStream(ArchiveResource)
                ?? throw new InvalidOperationException("No se encontro el contenido de la aplicacion.");
            using var archive = new ZipArchive(archiveStream, ZipArchiveMode.Read);
            var root = Path.GetFullPath(InstallDirectory + Path.DirectorySeparatorChar);
            var total = Math.Max(archive.Entries.Count, 1);
            var current = 0;
            foreach (var entry in archive.Entries)
            {
                var targetPath = Path.GetFullPath(Path.Combine(InstallDirectory, entry.FullName));
                if (!targetPath.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidDataException("El paquete contiene una ruta invalida.");
                }

                if (string.IsNullOrEmpty(entry.Name))
                {
                    Directory.CreateDirectory(targetPath);
                }
                else
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(targetPath)!);
                    entry.ExtractToFile(targetPath, true);
                }

                current++;
                report?.Invoke($"Copiando archivos ({current} de {total})...");
            }
        }

        private static void StopInstalledApp()
        {
            foreach (var process in Process.GetProcessesByName("pcb_boxing_system"))
            {
                try
                {
                    if (string.Equals(process.MainModule?.FileName, InstalledPath, StringComparison.OrdinalIgnoreCase))
                    {
                        process.Kill(true);
                        process.WaitForExit(5000);
                    }
                }
                catch
                {
                    // The app may already be closed or inaccessible.
                }
                finally
                {
                    process.Dispose();
                }
            }
        }

        private static void RegisterUninstall()
        {
            using var key = Registry.CurrentUser.CreateSubKey(UninstallKeyPath);
            if (key is null)
            {
                throw new InvalidOperationException("No se pudo registrar AIRE en Windows.");
            }

            key.SetValue("DisplayName", ProductName);
            key.SetValue("DisplayVersion", DisplayVersion);
            key.SetValue("Publisher", "Ilsan");
            key.SetValue("InstallLocation", InstallDirectory);
            key.SetValue("DisplayIcon", $"{InstalledPath},0");
            key.SetValue("UninstallString", $"\"{UninstallerPath}\" --uninstall");
            key.SetValue("QuietUninstallString", $"\"{UninstallerPath}\" --uninstall");
            key.SetValue("NoModify", 1, RegistryValueKind.DWord);
            key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
        }

        private static void CreateShortcuts()
        {
            var desktopPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                "Ilsan Packing System.lnk");
            var startMenuDirectory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Programs), ProductName);
            var startMenuPath = Path.Combine(startMenuDirectory, "Ilsan Packing System.lnk");
            Directory.CreateDirectory(startMenuDirectory);

            var shellType = Type.GetTypeFromProgID("WScript.Shell")
                ?? throw new InvalidOperationException("No se pudo crear el acceso directo de Windows.");
            dynamic shell = Activator.CreateInstance(shellType)
                ?? throw new InvalidOperationException("No se pudo iniciar el creador de accesos directos.");
            try
            {
                foreach (var shortcutPath in new[] { desktopPath, startMenuPath })
                {
                    dynamic shortcut = shell.CreateShortcut(shortcutPath);
                    shortcut.TargetPath = InstalledPath;
                    shortcut.WorkingDirectory = InstallDirectory;
                    shortcut.IconLocation = $"{InstalledPath},0";
                    shortcut.Description = ProductName;
                    shortcut.Save();
                    Marshal.FinalReleaseComObject(shortcut);
                }
            }
            finally
            {
                Marshal.FinalReleaseComObject(shell);
            }
        }

        private static void RemoveShortcuts()
        {
            var desktopPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                "Ilsan Packing System.lnk");
            var startMenuDirectory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Programs), ProductName);
            var startMenuPath = Path.Combine(startMenuDirectory, "Ilsan Packing System.lnk");
            foreach (var path in new[] { desktopPath, startMenuPath })
            {
                if (File.Exists(path)) File.Delete(path);
            }

            if (Directory.Exists(startMenuDirectory) && !Directory.EnumerateFileSystemEntries(startMenuDirectory).Any())
            {
                Directory.Delete(startMenuDirectory);
            }
        }
    }
}
