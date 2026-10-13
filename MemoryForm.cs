using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Management;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Win32;

namespace TwoPlus.MemoryTool
{
    internal sealed class MemoryForm : Form
    {
        private readonly ComboBox folders = new ComboBox();
        private readonly Label current, advice, note, status;
        private readonly Button apply, restore;
        private readonly List<RadioButton> choices = new List<RadioButton>();
        private readonly TableLayoutPanel layout = new TableLayoutPanel();
        private readonly string backupRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"2plus\MemoryTool\Backups");
        private Configuration config;
        private int selectedGB = 8;
        private bool busy, discovering;
        private readonly double physical;
        private static readonly Color Accent = Color.FromArgb(79, 216, 186);

        [StructLayout(LayoutKind.Sequential)]
        private sealed class MemoryStatus
        {
            public uint Length = (uint)Marshal.SizeOf(typeof(MemoryStatus)), Load;
            public ulong TotalPhysical, AvailablePhysical, TotalPage, AvailablePage, TotalVirtual, AvailableVirtual, Extended;
        }
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GlobalMemoryStatusEx([In, Out] MemoryStatus memory);

        public MemoryForm()
        {
            Text = "2plus 僵毀記憶體設定  |  1.1.1";
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = new Font("Microsoft JhengHei UI", 10);
            ClientSize = new Size(840, 690); MinimumSize = new Size(650, 550);
            BackColor = Color.FromArgb(18, 25, 32); ForeColor = Color.FromArgb(229, 236, 240);
            AutoScroll = true;
            layout.Dock = DockStyle.Top; layout.AutoSize = true; layout.ColumnCount = 1;
            layout.Padding = new Padding(26, 20, 26, 22);
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100)); Controls.Add(layout);
            var memory = new MemoryStatus(); physical = GlobalMemoryStatusEx(memory) ? memory.TotalPhysical : 0;
            Row(Label("2PLUS  /  PROJECT ZOMBOID", 10, Accent));
            Row(Label("僵毀記憶體設定", 22, Color.White));
            Row(Label("先完全關閉遊戲，再選擇容量並套用。下次從 Steam 一般啟動時生效。"));
            Row(Label("01   遊戲安裝位置", 11, Accent));
            folders.DropDownStyle = ComboBoxStyle.DropDownList; folders.DropDownWidth = 740;
            folders.Margin = new Padding(0, 0, 0, 10); Row(folders);
            var find = Button("重新尋找", 140); var browse = Button("選擇遊戲資料夾", 180);
            Row(Flow(find, browse)); current = Label("正在尋找遊戲…"); Row(current);
            Row(Label("02   選擇記憶體上限", 11, Accent));
            Row(Label(physical > 0 ? "電腦記憶體：" + (physical / MemoryCore.GiB).ToString("0.#") + " GB" : "電腦記憶體：未能讀取"));
            var options = Flow();
            foreach (int gb in MemoryCore.Capacities)
            {
                var radio = new RadioButton { Appearance = Appearance.Button, Text = gb + " GB", Tag = gb, Size = new Size(130, 55), TextAlign = ContentAlignment.MiddleCenter,
                    Font = new Font("Segoe UI", 15, FontStyle.Bold), FlatStyle = FlatStyle.Flat, Cursor = Cursors.Hand, Margin = new Padding(0, 0, 10, 10) };
                radio.CheckedChanged += delegate { if (radio.Checked) { selectedGB = (int)radio.Tag; Safe(RefreshControls); } };
                options.Controls.Add(radio); choices.Add(radio);
            }
            Row(options); advice = Label(""); Row(advice); note = Label("", 10, Color.Khaki); Row(note);
            apply = Button("套用 8 GB", 170); apply.BackColor = Color.FromArgb(21, 131, 112);
            restore = Button("還原上次設定", 170); var backups = Button("開啟備份資料夾", 170); var help = Button("使用說明", 130);
            Row(Flow(apply, restore, backups, help)); status = Label("自動備份原設定，套用後重新讀取確認。", 11, Accent); Row(status);
            Row(Label("適用 Windows 10 / 11 64 位元。Steam 更新或驗證遊戲後，請重新確認設定。", 9));
            folders.SelectedIndexChanged += delegate { if (!discovering) Safe(ReadFolder); };
            find.Click += delegate { Safe(Discover); };
            browse.Click += delegate { Safe(Browse); };
            apply.Click += delegate { Safe(Apply); };
            restore.Click += delegate { Safe(Restore); };
            backups.Click += delegate { Safe(OpenBackups); };
            help.Click += delegate { MessageBox.Show(this,
                "1. 完全關閉遊戲。\r\n2. 選擇正確的 ProjectZomboid 安裝資料夾。\r\n3. 依總記憶體選擇容量並套用。\r\n4. 從 Steam 一般啟動。\r\n\r\n只改玩家端 ProjectZomboid64.json 的記憶體參數。每次修改前自動備份，舊版備份可繼續還原。\r\n不修改存檔、模組、伺服器或系統虛擬記憶體。\r\n\r\n只有 8 GB 記憶體的電腦不適用這五個選項，請先聯絡管理員。\r\n\r\n若安全軟體攔截，請保留偵測名稱交給發行者確認。",
                "使用說明 · 1.1.1", MessageBoxButtons.OK, MessageBoxIcon.Information); };
            choices[0].Checked = true;
            Resize += delegate { foreach (Control c in layout.Controls) if (c is Label) c.MaximumSize = new Size(Math.Max(250, ClientSize.Width - 75), 0); };
            Shown += delegate
            {
                var area = Screen.FromControl(this).WorkingArea;
                MinimumSize = new Size(Math.Min(650, area.Width - 24), Math.Min(550, area.Height - 24));
                Size = new Size(Math.Min(Width, area.Width - 24), Math.Min(Height, area.Height - 24));
                Safe(Discover);
            };
        }
        private static Label Label(string text, int size = 10, Color? color = null)
        { return new Label { Text = text, AutoSize = true, MaximumSize = new Size(740, 0), Font = new Font("Microsoft JhengHei UI", size), ForeColor = color ?? Color.FromArgb(166, 183, 199), Margin = new Padding(0, 0, 0, 12) }; }
        private static Button Button(string text, int width)
        { return new Button { Text = text, Size = new Size(width, 40), FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(35, 47, 59), ForeColor = Color.White, Cursor = Cursors.Hand, Margin = new Padding(0, 0, 10, 8) }; }
        private static FlowLayoutPanel Flow(params Control[] controls)
        { var panel = new FlowLayoutPanel { AutoSize = true, WrapContents = true }; panel.Controls.AddRange(controls); return panel; }
        private void Row(Control c)
        { int row = layout.RowCount++; layout.RowStyles.Add(new RowStyle(SizeType.AutoSize)); c.Dock = DockStyle.Top; layout.Controls.Add(c, 0, row); }
        private void Safe(Action action)
        {
            try { action(); }
            catch (Exception e)
            {
                string message = e is UnauthorizedAccessException ? "無法寫入資料夾。請確認安裝位置與檔案權限；需要時關閉工具，再以系統管理員身分執行。" : e.Message;
                status.Text = message; status.ForeColor = Color.Salmon;
                MessageBox.Show(this, message, "未能完成", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
        private void RefreshControls()
        {
            var a = MemoryCore.Assess(selectedGB, physical); advice.Text = a.Text; advice.ForeColor = a.Block || a.Confirm ? Color.Khaki : Color.LightSlateGray;
            apply.Text = "套用 " + selectedGB + " GB"; apply.Enabled = config != null && !a.Block && !busy;
            restore.Enabled = false; note.Text = "";
            if (config != null)
            {
                current.Text = MemoryCore.Display(config); note.Text = MemoryCore.MakePlan(config, selectedGB).Note;
                restore.Enabled = !busy && MemoryCore.LatestBackup(config.Path, backupRoot) != null;
            }
            foreach (var radio in choices) radio.BackColor = radio.Checked ? Color.FromArgb(21, 131, 112) : Color.FromArgb(35, 47, 59);
        }
        private void ReadFolder()
        {
            config = null;
            current.Text = "找不到遊戲。請選擇含有 ProjectZomboid64.json 的遊戲安裝資料夾。";
            try { if (folders.SelectedItem != null) config = MemoryCore.Read(Path.Combine((string)folders.SelectedItem, "ProjectZomboid64.json")); }
            finally { RefreshControls(); }
        }
        private void Discover()
        {
            var roots = new List<string>();
            foreach (var entry in new[] { new[] { @"HKEY_CURRENT_USER\Software\Valve\Steam", "SteamPath" }, new[] { @"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath" }, new[] { @"HKEY_LOCAL_MACHINE\SOFTWARE\Valve\Steam", "InstallPath" } })
                try { var value = Registry.GetValue(entry[0], entry[1], null) as string; if (value != null) roots.Add(value); } catch (System.Security.SecurityException) { } catch (UnauthorizedAccessException) { }
            foreach (string folder in new[] { Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86) })
                if (!string.IsNullOrEmpty(folder)) roots.Add(Path.Combine(folder, "Steam"));
            string previous = folders.SelectedItem as string;
            string[] found = MemoryCore.Candidates(roots, new[] { AppDomain.CurrentDomain.BaseDirectory, previous });
            discovering = true;
            try { folders.Items.Clear(); folders.Items.AddRange(found); if (found.Length > 0) folders.SelectedItem = found.Contains(previous) ? previous : found[0]; }
            finally { discovering = false; }
            ReadFolder();
            if (found.Length > 1) status.Text = "找到多個遊戲目錄，請選平常使用的那一個。";
        }
        private void Browse()
        {
            using (var dialog = new FolderBrowserDialog { Description = "選擇含有 ProjectZomboid64.json 的 Steam 遊戲資料夾。", ShowNewFolderButton = false })
            {
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                MemoryCore.Read(Path.Combine(dialog.SelectedPath, "ProjectZomboid64.json"));
                if (!folders.Items.Contains(dialog.SelectedPath)) folders.Items.Add(dialog.SelectedPath);
                folders.SelectedItem = dialog.SelectedPath; ReadFolder();
            }
        }
        private static void AssertClosed()
        {
            var processes = new List<ProcessInfo>();
            using (var search = new ManagementObjectSearcher("SELECT Name,CommandLine FROM Win32_Process WHERE Name='ProjectZomboid64.exe' OR Name='ProjectZomboid32.exe' OR Name='ProjectZomboid.exe' OR Name='java.exe' OR Name='javaw.exe'"))
            using (var result = search.Get()) foreach (ManagementObject row in result) using (row)
                processes.Add(new ProcessInfo { Name = row["Name"] as string, CommandLine = row["CommandLine"] as string });
            if (MemoryCore.GameRunning(processes)) throw new IOException("僵毀仍在執行。請完全退出到桌面，再套用或還原。");
        }
        private void Commit(Plan plan, string action)
        {
            busy = true;
            try
            {
                RefreshControls(); var result = MemoryCore.Save(config, plan, backupRoot, action, AssertClosed);
                config = MemoryCore.Read(config.Path); current.Text = MemoryCore.Display(config);
                status.ForeColor = Accent;
                status.Text = result.Warning.Length > 0 ? result.Warning : !result.Changed ? "設定已相同，無需再次修改。" : action == "restore" ? "已還原上次記憶體設定，其他啟動參數已保留。" : "設定完成並已備份。現在可從 Steam 一般啟動遊戲。";
            }
            finally { busy = false; RefreshControls(); }
        }
        private void Apply()
        {
            AssertClosed(); ReadFolder(); if (config == null) throw new IOException("請先選擇遊戲資料夾。");
            var assessment = MemoryCore.Assess(selectedGB, physical); if (assessment.Block) throw new IOException(assessment.Text);
            var plan = MemoryCore.MakePlan(config, selectedGB);
            if ((assessment.Confirm || plan.Note.Length > 0) && MessageBox.Show(this, "將設定為 " + selectedGB + " GB。\r\n\r\n" + assessment.Text + "\r\n" + plan.Note + "\r\n\r\n是否套用？", "確認記憶體設定", MessageBoxButtons.YesNo, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2) != DialogResult.Yes) return;
            Commit(plan, "set");
        }
        private void Restore()
        {
            AssertClosed(); ReadFolder(); if (config == null) throw new IOException("請先選擇遊戲資料夾。");
            var backup = MemoryCore.LatestBackup(config.Path, backupRoot); if (backup == null) throw new IOException("沒有找到這份遊戲設定的有效備份。");
            var plan = MemoryCore.RestorePlan(config, backup);
            if (MessageBox.Show(this, MemoryCore.Display(backup) + "\r\n\r\n" + plan.Note + "\r\n是否還原？", "還原上次設定", MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2) == DialogResult.Yes) Commit(plan, "restore");
        }
        private void OpenBackups()
        {
            string folder = config == null ? backupRoot : MemoryCore.BackupDirectory(config.Path, backupRoot);
            if (!Directory.Exists(folder)) throw new IOException("套用成功後才會建立備份。");
            // The only optional child process opens the requested backup folder.
            Process.Start(new ProcessStartInfo { FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "explorer.exe"), Arguments = "\"" + folder + "\"", UseShellExecute = false });
        }
    }
}
