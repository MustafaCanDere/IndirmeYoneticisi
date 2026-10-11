using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

// Gomulu PowerShell uygulamasini %LOCALAPPDATA%\IndirmeYoneticisi altina cikarip gizli pencerede calistirir.
static class Launcher
{
    [STAThread]
    static void Main(string[] args)
    {
        try
        {
            string root = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "IndirmeYoneticisi");
            Directory.CreateDirectory(root);

            Assembly asm = Assembly.GetExecutingAssembly();
            foreach (string name in asm.GetManifestResourceNames())
            {
                if (!name.StartsWith("app/")) continue;
                string target = Path.Combine(root, name.Substring(4).Replace('/', Path.DirectorySeparatorChar));
                // config.js uygulama tarafindan yazilan gizli anahtari icerir; varsa dokunma.
                if (Path.GetFileName(target) == "config.js" && File.Exists(target)) continue;
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                using (Stream s = asm.GetManifestResourceStream(name))
                using (FileStream f = File.Create(target))
                    s.CopyTo(f);
            }

            var sb = new StringBuilder();
            sb.Append("-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File \"");
            sb.Append(Path.Combine(root, "IndirmeYoneticisi.ps1")).Append('"');
            foreach (string a in args)
                if (a.Equals("-Gizli", StringComparison.OrdinalIgnoreCase)) sb.Append(" -Gizli");

            var psi = new ProcessStartInfo("powershell.exe", sb.ToString());
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WorkingDirectory = root;
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "İndirme Yöneticisi başlatılamadı");
        }
    }
}
