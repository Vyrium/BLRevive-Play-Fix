using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("BLRevive Steam Play Fix")]
[assembly: AssemblyDescription("Compatibility launcher for Blacklight: Retribution / BLRevive")]
[assembly: AssemblyCompany("BLRevive Community")]
[assembly: AssemblyProduct("BLRevive Steam Play Fix")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

internal static class Program
{
    private const string LauncherVersion = "1.1.0";
    private const string GameExeName = "FoxGame-win32-Shipping.exe";
    private const string ConfigFileName = "BLReviveLauncher.ini";
    private const string LogFileName = "BLReviveSteamLauncher.log";

    private static string _logPath;

    [STAThread]
    private static int Main()
    {
        string baseDir = AppDomain.CurrentDomain.BaseDirectory;
        _logPath = Path.Combine(baseDir, LogFileName);

        try
        {
            RotateLogIfNeeded();
            Log("============================================================");
            Log("BLRevive Steam Play Fix " + LauncherVersion);
            Log("Started: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss zzz"));
            Log("Launcher path: " + Application.ExecutablePath);
            Log("Working directory: " + baseDir);
            Log("OS: " + Environment.OSVersion);
            Log("64-bit OS: " + Environment.Is64BitOperatingSystem);
            Log("64-bit launcher process: " + Environment.Is64BitProcess);

            string gameExe = Path.Combine(baseDir, GameExeName);
            string iniFile = Path.Combine(baseDir, ConfigFileName);

            if (!File.Exists(gameExe))
            {
                return Fail("Could not find the real game executable:\n\n" + gameExe +
                    "\n\nSteam Verify Integrity can restore missing game files.");
            }

            if (!File.Exists(iniFile))
            {
                return Fail("Could not find the launcher configuration:\n\n" + iniFile +
                    "\n\nReinstall the BLRevive Steam Play Fix or restore the INI file.");
            }

            IniFile ini = IniFile.Load(iniFile);

            string zcureHost = ini.Get("ZCure", "Host");
            string zcurePortText = ini.Get("ZCure", "Port");
            string presenceHost = ini.Get("Presence", "Host");
            string presencePortText = ini.Get("Presence", "Port");

            int zcurePort;
            int presencePort;

            if (!ValidateHost(zcureHost))
                return Fail("Invalid [ZCure] Host value in " + ConfigFileName + ".");

            if (!ValidatePort(zcurePortText, out zcurePort))
                return Fail("Invalid [ZCure] Port value in " + ConfigFileName + ".");

            if (!ValidateHost(presenceHost))
                return Fail("Invalid [Presence] Host value in " + ConfigFileName + ".");

            if (!ValidatePort(presencePortText, out presencePort))
                return Fail("Invalid [Presence] Port value in " + ConfigFileName + ".");

            Log("Configured ZCure endpoint: " + zcureHost + ":" + zcurePort);
            Log("Configured Presence endpoint: " + presenceHost + ":" + presencePort);

            string[] originalArgs = Environment.GetCommandLineArgs().Skip(1).ToArray();
            LogArguments("Arguments received from Steam", originalArgs);

            List<string> forwardedArgs = new List<string>();
            List<string> removedArgs = new List<string>();

            foreach (string arg in originalArgs)
            {
                if (IsEndpointArgument(arg))
                    removedArgs.Add(arg);
                else
                    forwardedArgs.Add(arg);
            }

            LogArguments("Obsolete/duplicate endpoint arguments removed", removedArgs.ToArray());

            // Put the authoritative BLRevive endpoints last after all non-network user arguments.
            forwardedArgs.Add("-zcureurl=" + zcureHost);
            forwardedArgs.Add("-zcureport=" + zcurePort);
            forwardedArgs.Add("-presenceurl=" + presenceHost);
            forwardedArgs.Add("-presenceport=" + presencePort);

            LogArguments("Arguments forwarded to Blacklight", forwardedArgs.ToArray());

            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = gameExe;
            startInfo.WorkingDirectory = baseDir;
            startInfo.Arguments = BuildCommandLine(forwardedArgs);
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;

            Log("Launching: " + gameExe);

            Process game = Process.Start(startInfo);
            if (game == null)
                return Fail("Windows failed to start Blacklight: Retribution.");

            Log("Game process started. PID=" + game.Id);
            Log("Waiting for game process to exit so Steam retains Running state...");

            game.WaitForExit();
            int exitCode = game.ExitCode;
            Log("Game process exited. ExitCode=" + exitCode);
            game.Dispose();
            Log("Launcher exiting normally.");
            return exitCode;
        }
        catch (Exception ex)
        {
            Log("UNHANDLED EXCEPTION:");
            Log(ex.ToString());
            ShowError("Unexpected launcher error:\n\n" + ex.Message +
                "\n\nSee " + LogFileName + " for details.");
            return 1;
        }
    }

    private static bool IsEndpointArgument(string argument)
    {
        if (String.IsNullOrEmpty(argument))
            return false;

        string normalized = argument.Trim();
        while (normalized.StartsWith("-") || normalized.StartsWith("/"))
            normalized = normalized.Substring(1);

        return normalized.StartsWith("zcureurl=", StringComparison.OrdinalIgnoreCase) ||
               normalized.StartsWith("zcureport=", StringComparison.OrdinalIgnoreCase) ||
               normalized.StartsWith("presenceurl=", StringComparison.OrdinalIgnoreCase) ||
               normalized.StartsWith("presenceport=", StringComparison.OrdinalIgnoreCase);
    }

    private static bool ValidateHost(string host)
    {
        if (String.IsNullOrWhiteSpace(host))
            return false;

        if (host.Length > 253)
            return false;

        foreach (char c in host)
        {
            if (Char.IsWhiteSpace(c) || c == '"' || c == '\'' || c == ';')
                return false;
        }

        return true;
    }

    private static bool ValidatePort(string text, out int port)
    {
        return Int32.TryParse(text, out port) && port >= 1 && port <= 65535;
    }

    private static string BuildCommandLine(IEnumerable<string> arguments)
    {
        return String.Join(" ", arguments.Select(QuoteArgument).ToArray());
    }

    // Correct Windows command-line quoting for CreateProcess/CommandLineToArgvW-style parsing.
    private static string QuoteArgument(string argument)
    {
        if (argument == null || argument.Length == 0)
            return "\"\"";

        if (!argument.Any(c => Char.IsWhiteSpace(c) || c == '"'))
            return argument;

        StringBuilder result = new StringBuilder();
        result.Append('"');
        int backslashes = 0;

        foreach (char c in argument)
        {
            if (c == '\\')
            {
                backslashes++;
                continue;
            }

            if (c == '"')
            {
                result.Append(new string('\\', backslashes * 2 + 1));
                result.Append('"');
                backslashes = 0;
                continue;
            }

            if (backslashes > 0)
            {
                result.Append(new string('\\', backslashes));
                backslashes = 0;
            }

            result.Append(c);
        }

        if (backslashes > 0)
            result.Append(new string('\\', backslashes * 2));

        result.Append('"');
        return result.ToString();
    }

    private static int Fail(string message)
    {
        Log("ERROR: " + message.Replace("\r", " ").Replace("\n", " "));
        ShowError(message + "\n\nDiagnostic log:\n" + _logPath);
        return 1;
    }

    private static void ShowError(string message)
    {
        MessageBox.Show(message, "BLRevive Steam Play Fix",
            MessageBoxButtons.OK, MessageBoxIcon.Error);
    }

    private static void LogArguments(string heading, string[] args)
    {
        Log(heading + " (" + args.Length + "):");
        if (args.Length == 0)
        {
            Log("  <none>");
            return;
        }

        for (int i = 0; i < args.Length; i++)
            Log("  [" + i + "] " + RedactSensitiveArgument(args[i]));
    }

    private static string RedactSensitiveArgument(string arg)
    {
        if (arg == null)
            return "<null>";

        string lower = arg.ToLowerInvariant();
        string[] sensitive = { "password=", "passwd=", "token=", "secret=", "apikey=", "api_key=", "auth=" };

        foreach (string marker in sensitive)
        {
            int index = lower.IndexOf(marker, StringComparison.Ordinal);
            if (index >= 0)
                return arg.Substring(0, index + marker.Length) + "<redacted>";
        }

        return arg;
    }

    private static void RotateLogIfNeeded()
    {
        try
        {
            if (!File.Exists(_logPath))
                return;

            FileInfo info = new FileInfo(_logPath);
            if (info.Length < 1024 * 1024)
                return;

            string oldPath = _logPath + ".old";
            if (File.Exists(oldPath))
                File.Delete(oldPath);
            File.Move(_logPath, oldPath);
        }
        catch
        {
            // Logging must never prevent the game from launching.
        }
    }

    private static void Log(string message)
    {
        try
        {
            File.AppendAllText(_logPath,
                "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + "] " + message + Environment.NewLine,
                Encoding.UTF8);
        }
        catch
        {
            // Logging must never prevent the game from launching.
        }
    }

    private sealed class IniFile
    {
        private readonly Dictionary<string, Dictionary<string, string>> _sections =
            new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);

        public static IniFile Load(string path)
        {
            IniFile ini = new IniFile();
            string currentSection = "";

            foreach (string rawLine in File.ReadAllLines(path))
            {
                string line = rawLine.Trim();
                if (line.Length == 0 || line.StartsWith(";") || line.StartsWith("#"))
                    continue;

                if (line.StartsWith("[") && line.EndsWith("]") && line.Length >= 2)
                {
                    currentSection = line.Substring(1, line.Length - 2).Trim();
                    continue;
                }

                int equals = line.IndexOf('=');
                if (equals <= 0)
                    continue;

                string key = line.Substring(0, equals).Trim();
                string value = line.Substring(equals + 1).Trim();

                Dictionary<string, string> section;
                if (!ini._sections.TryGetValue(currentSection, out section))
                {
                    section = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    ini._sections[currentSection] = section;
                }

                section[key] = value;
            }

            return ini;
        }

        public string Get(string sectionName, string key)
        {
            Dictionary<string, string> section;
            string value;
            if (_sections.TryGetValue(sectionName, out section) && section.TryGetValue(key, out value))
                return value;
            return null;
        }
    }
}
