using System;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("2plus Project Zomboid Memory Tool")]
[assembly: AssemblyDescription("Back up, set and restore Project Zomboid client memory limits.")]
[assembly: AssemblyCompany("2plus")]
[assembly: AssemblyProduct("2plus Memory Tool")]
[assembly: AssemblyVersion("1.1.1.0")]
[assembly: AssemblyFileVersion("1.1.1.0")]
[assembly: System.Runtime.Versioning.TargetFramework(".NETFramework,Version=v4.6.2")]

namespace TwoPlus.MemoryTool
{
    internal static class Program
    {
        [STAThread]
        private static int Main()
        {
            bool owner = false;
            try
            {
                if (Environment.OSVersion.Platform != PlatformID.Win32NT || !Environment.Is64BitOperatingSystem)
                    throw new PlatformNotSupportedException("請在 Windows 10 / 11 的 64 位元電腦執行。");
                using (var mutex = new Mutex(true, @"Local\TwoPlusMemoryTool", out owner))
                {
                    if (!owner) throw new InvalidOperationException("工具已經開啟，請回到原本的視窗。");
                    try
                    {
                        Application.EnableVisualStyles();
                        Application.SetCompatibleTextRenderingDefault(false);
                        using (var form = new MemoryForm()) Application.Run(form);
                    }
                    finally { mutex.ReleaseMutex(); }
                }
                return 0;
            }
            catch (Exception error) { MessageBox.Show(error.Message, "2plus 記憶體設定", MessageBoxButtons.OK, MessageBoxIcon.Warning); return 1; }
        }
    }
}
