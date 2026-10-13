using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace TwoPlus.MemoryTool
{
    // A strict, bounded JSON reader that retains source offsets. No evaluation,
    // script engine, network access or serialization of unrelated launcher options.
    public sealed class JsonNode
    {
        public char Kind;
        public int Start, End;
        public string Text;
        public Dictionary<string, JsonNode> Properties;
        public List<JsonNode> Items;
        public JsonNode Get(string key) { JsonNode n; return Properties != null && Properties.TryGetValue(key, out n) ? n : null; }
        public string String(string key) { var n = Get(key); return n != null && n.Kind == 's' ? n.Text : null; }
    }

    public sealed class JsonReader
    {
        private readonly string text;
        private int pos;
        private JsonReader(string source) { text = source; }
        private FormatException Error() { return new FormatException("設定不是有效的 JSON，或包含重複欄位。未修改檔案。（位置 " + pos + "）"); }
        private void White() { while (pos < text.Length && " \t\r\n".IndexOf(text[pos]) >= 0) pos++; }
        private bool Take(char c) { White(); if (pos < text.Length && text[pos] == c) { pos++; return true; } return false; }
        private void Need(char c) { if (!Take(c)) throw Error(); }
        private string ReadString()
        {
            Need('"'); var b = new StringBuilder();
            while (pos < text.Length)
            {
                char c = text[pos++];
                if (c == '"') return b.ToString();
                if (c < 32) throw Error();
                if (c != '\\') { b.Append(c); continue; }
                if (pos >= text.Length) throw Error();
                c = text[pos++];
                switch (c)
                {
                    case '"': case '\\': case '/': b.Append(c); break;
                    case 'b': b.Append('\b'); break; case 'f': b.Append('\f'); break;
                    case 'n': b.Append('\n'); break; case 'r': b.Append('\r'); break; case 't': b.Append('\t'); break;
                    case 'u':
                        ushort code;
                        if (pos + 4 > text.Length || !ushort.TryParse(text.Substring(pos, 4), NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture, out code)) throw Error();
                        b.Append((char)code); pos += 4; break;
                    default: throw Error();
                }
            }
            throw Error();
        }
        private JsonNode Value(int depth)
        {
            White(); if (depth > 64 || pos >= text.Length) throw Error();
            var n = new JsonNode { Start = pos }; char c = text[pos];
            if (c == '"') { n.Kind = 's'; n.Text = ReadString(); }
            else if (c == '{')
            {
                n.Kind = 'o'; n.Properties = new Dictionary<string, JsonNode>(StringComparer.Ordinal); pos++;
                if (!Take('}')) do
                {
                    string key = ReadString(); Need(':'); var value = Value(depth + 1);
                    if (n.Properties.ContainsKey(key)) throw Error(); n.Properties.Add(key, value);
                    if (Take('}')) break; Need(',');
                } while (true);
            }
            else if (c == '[')
            {
                n.Kind = 'a'; n.Items = new List<JsonNode>(); pos++;
                if (!Take(']')) do { n.Items.Add(Value(depth + 1)); if (Take(']')) break; Need(','); } while (true);
            }
            else
            {
                int start = pos;
                while (pos < text.Length && " \t\r\n,]}".IndexOf(text[pos]) < 0) pos++;
                string atom = text.Substring(start, pos - start);
                if (atom == "null") n.Kind = '0';
                else if (atom == "true" || atom == "false") n.Kind = 'b';
                else if (Regex.IsMatch(atom, @"\A-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?\z")) n.Kind = 'n';
                else throw Error();
                n.Text = atom;
            }
            n.End = pos; return n;
        }
        public static JsonNode Parse(string text)
        {
            if (text == null || text.Length > 1024 * 1024) throw new FormatException("設定檔過大或無內容。未修改檔案。");
            var r = new JsonReader(text); var n = r.Value(0); r.White(); if (r.pos != text.Length) throw r.Error(); return n;
        }
        public static string Quote(string text)
        {
            var b = new StringBuilder("\"");
            foreach (char c in text)
            {
                if (c == '"' || c == '\\') { b.Append('\\'); b.Append(c); }
                else if (c < 32) b.Append("\\u" + ((int)c).ToString("x4"));
                else b.Append(c);
            }
            return b.Append('"').ToString();
        }
    }

    public sealed class Heap { public string Kind, Value; public decimal Bytes; public JsonNode Token; }
    public sealed class Document
    {
        public string Text;
        public JsonNode Root, Args;
        public List<Heap> Heaps = new List<Heap>();
    }
    public sealed class Configuration { public string Path, Hash; public byte[] Bytes; public bool Bom; public Document Document; }
    public sealed class Plan { public string Text, Note = ""; }
    public sealed class Advice { public bool Block, Confirm; public string Text; }
    public sealed class SaveResult { public bool Changed; public string BackupPath, Warning = ""; }
    public sealed class ProcessInfo { public string Name, CommandLine; }

    public static class MemoryCore
    {
        public const long GiB = 1073741824;
        public static readonly int[] Capacities = { 8, 10, 12, 14, 16 };
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false, true);
        public static string Hash(byte[] bytes)
        {
            using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant();
        }
        public static decimal HeapBytes(string value)
        {
            var m = Regex.Match(value, @"\A-(?:Xmx|Xms)([0-9]+)([kKmMgG]?)\z");
            if (!m.Success) throw new FormatException("無法辨識記憶體參數：" + value + "。未修改檔案。");
            decimal size;
            if (!decimal.TryParse(m.Groups[1].Value, NumberStyles.None, CultureInfo.InvariantCulture, out size)) throw new FormatException("記憶體參數數字過大。");
            string unit = m.Groups[2].Value.ToLowerInvariant();
            try { return size * (unit == "g" ? GiB : unit == "m" ? 1048576 : unit == "k" ? 1024 : 1); }
            catch (OverflowException) { throw new FormatException("記憶體參數數字過大。"); }
        }
        private static bool IsHeap(string s) { return s.StartsWith("-Xmx", StringComparison.Ordinal) || s.StartsWith("-Xms", StringComparison.Ordinal); }
        private static bool AlternateHeap(string s) { return Regex.IsMatch(s, @"\A-XX:(MaxHeapSize|InitialHeapSize|SoftMaxHeapSize)="); }
        private static void StringArray(JsonNode n)
        {
            if (n == null || n.Kind != 'a' || n.Items.Any(x => x.Kind != 's')) throw new FormatException("vmArgs 必須是文字清單，未修改檔案。");
        }
        private static void CheckWindows(JsonNode n)
        {
            if (n == null) return;
            if (n.Kind == 'o') foreach (var pair in n.Properties)
            {
                if (pair.Key == "vmArgs")
                {
                    StringArray(pair.Value);
                    if (pair.Value.Items.Any(x => IsHeap(x.Text) || AlternateHeap(x.Text))) throw new FormatException("Windows 分支另有記憶體參數，可能覆蓋主要設定。未修改檔案。");
                }
                CheckWindows(pair.Value);
            }
            else if (n.Kind == 'a') foreach (var item in n.Items) CheckWindows(item);
        }
        public static Document ReadText(string text)
        {
            var root = JsonReader.Parse(text);
            if (root.Kind != 'o' || !Regex.IsMatch(root.String("mainClass") ?? "", @"\Azombie[/.]gameStates[/.]MainScreenState\z"))
                throw new FormatException("這不是僵毀 64 位元玩家端設定；不會修改專用伺服器設定。");
            var d = new Document { Text = text, Root = root, Args = root.Get("vmArgs") };
            StringArray(d.Args); CheckWindows(root.Get("windows"));
            foreach (var arg in d.Args.Items)
            {
                if (AlternateHeap(arg.Text)) throw new FormatException("發現另外設定的 Java 記憶體參數，未修改檔案。");
                if (!IsHeap(arg.Text)) continue;
                string kind = arg.Text.Substring(0, 4);
                if (d.Heaps.Any(h => h.Kind == kind)) throw new FormatException("存在重複的 " + kind + "，未修改檔案。");
                d.Heaps.Add(new Heap { Kind = kind, Value = arg.Text, Bytes = HeapBytes(arg.Text), Token = arg });
            }
            return d;
        }
        public static Configuration Read(string path)
        {
            path = System.IO.Path.GetFullPath(path);
            if (new FileInfo(path).Length > 1024 * 1024) throw new FormatException("設定檔過大，未修改檔案。");
            byte[] bytes = File.ReadAllBytes(path);
            bool bom = bytes.Length >= 3 && bytes[0] == 239 && bytes[1] == 187 && bytes[2] == 191;
            int offset = bom ? 3 : 0;
            return new Configuration { Path = path, Bytes = bytes, Hash = Hash(bytes), Bom = bom, Document = ReadText(Utf8.GetString(bytes, offset, bytes.Length - offset)) };
        }
        public static string SetHeaps(Document d, IEnumerable<string> values)
        {
            var wanted = new Dictionary<string, string>(StringComparer.Ordinal);
            foreach (string value in values) { HeapBytes(value); wanted.Add(value.Substring(0, 4), value); }
            string next = d.Text;
            if (d.Heaps.Any(h => !wanted.ContainsKey(h.Kind)))
            {
                var kept = new List<string>();
                foreach (var token in d.Args.Items)
                {
                    if (IsHeap(token.Text))
                    {
                        string key = token.Text.Substring(0, 4);
                        if (wanted.ContainsKey(key)) { kept.Add(JsonReader.Quote(wanted[key])); wanted.Remove(key); }
                    }
                    else kept.Add(d.Text.Substring(token.Start, token.End - token.Start));
                }
                foreach (string key in new[] { "-Xmx", "-Xms" }) if (wanted.ContainsKey(key)) kept.Add(JsonReader.Quote(wanted[key]));
                string nl = d.Text.Contains("\r\n") ? "\r\n" : "\n";
                string body = kept.Count == 0 ? "" : nl + "    " + string.Join("," + nl + "    ", kept) + nl + "  ";
                next = next.Remove(d.Args.Start + 1, d.Args.End - d.Args.Start - 2).Insert(d.Args.Start + 1, body);
            }
            else
            {
                foreach (var heap in d.Heaps.OrderByDescending(h => h.Token.Start))
                {
                    next = next.Remove(heap.Token.Start, heap.Token.End - heap.Token.Start).Insert(heap.Token.Start, JsonReader.Quote(wanted[heap.Kind])); wanted.Remove(heap.Kind);
                }
                if (wanted.Count > 0)
                {
                    var fresh = ReadText(next); var append = new List<string>();
                    foreach (string key in new[] { "-Xmx", "-Xms" }) if (wanted.ContainsKey(key)) append.Add(JsonReader.Quote(wanted[key]));
                    next = next.Insert(fresh.Args.End - 1, (fresh.Args.Items.Count > 0 ? ", " : "") + string.Join(", ", append));
                }
            }
            ReadText(next); return next;
        }
        private static void Capacity(int gb) { if (!Capacities.Contains(gb)) throw new ArgumentException("請選擇 8、10、12、14 或 16 GB。"); }
        public static Plan MakePlan(Configuration c, int gb)
        {
            Capacity(gb); var p = new Plan(); var values = new List<string> { "-Xmx" + (gb * 1024) + "m" };
            var initial = c.Document.Heaps.FirstOrDefault(h => h.Kind == "-Xms");
            if (initial != null)
            {
                values.Add(initial.Bytes > gb * (decimal)GiB ? "-Xms1024m" : initial.Value);
                if (initial.Bytes > gb * (decimal)GiB) p.Note = "原本初始記憶體高於新上限，將一併調低為 1 GB。";
            }
            p.Text = SetHeaps(c.Document, values); return p;
        }
        public static Plan RestorePlan(Configuration c, Configuration backup)
        { return new Plan { Text = SetHeaps(c.Document, backup.Document.Heaps.Select(h => h.Value)), Note = "只還原記憶體設定，保留目前版本的其他啟動參數。" }; }
        public static Advice Assess(int gb, double physicalBytes)
        {
            Capacity(gb);
            if (physicalBytes <= 0) return new Advice { Confirm = true, Text = "無法讀取總記憶體，請先確認電腦有足夠容量。" };
            double remaining = physicalBytes - gb * (double)GiB;
            if (remaining < GiB) return new Advice { Block = true, Text = "剩餘容量不足以供 Windows 使用，請選較低容量。" };
            if (remaining < 4d * GiB || gb * (double)GiB > physicalBytes * 0.75) return new Advice { Confirm = true, Text = "留給 Windows 和其他程式的容量較少，建議選較低容量。" };
            return new Advice { Text = "這是 Java 記憶體上限，不會立即占滿，也不是遊戲的總占用。" };
        }
        public static string Display(Configuration c)
        {
            var heap = c.Document.Heaps.FirstOrDefault(h => h.Kind == "-Xmx");
            return heap == null ? "目前設定：由 Java 自動決定" : "目前設定：" + (heap.Bytes / GiB).ToString("0.##") + " GB";
        }
        public static string BackupDirectory(string config, string backupRoot)
        { return Path.Combine(backupRoot, Hash(Utf8.GetBytes(Path.GetFullPath(config).ToLowerInvariant()))); }
        public static Configuration LatestBackup(string config, string backupRoot)
        {
            string dir = BackupDirectory(config, backupRoot); if (!Directory.Exists(dir)) return null;
            foreach (string file in Directory.GetFiles(dir, "*.applied.json").OrderByDescending(p => p, StringComparer.Ordinal)) try
            {
                if (new FileInfo(file).Length > 1024 * 1024) continue;
                var record = JsonReader.Parse(File.ReadAllText(file, Utf8)); string name = record.String("BackupName");
                if (record.String("Action") != "set" || !string.Equals(record.String("ConfigPath"), Path.GetFullPath(config), StringComparison.OrdinalIgnoreCase)) continue;
                if (name == null || !Regex.IsMatch(name, @"\A[0-9]{8}-[0-9]{6}-[0-9]{7}-[a-f0-9]{32}\.json\z")) continue;
                var saved = Read(Path.Combine(dir, name)); if (saved.Hash == record.String("BeforeHash")) return saved;
            }
            catch (IOException) { } catch (FormatException) { } catch (UnauthorizedAccessException) { } catch (DecoderFallbackException) { }
            return null;
        }
        public static SaveResult Save(Configuration c, Plan plan, string backupRoot, string action, Action beforeCommit)
        {
            if (action != "set" && action != "restore") throw new ArgumentException("Invalid backup action");
            ReadText(plan.Text); if (c.Document.Text == plan.Text) return new SaveResult();
            byte[] body = Utf8.GetBytes(plan.Text);
            byte[] bytes = c.Bom ? new byte[] { 239, 187, 191 }.Concat(body).ToArray() : body;
            string dir = BackupDirectory(c.Path, backupRoot); Directory.CreateDirectory(dir);
            string id = DateTime.Now.ToString("yyyyMMdd-HHmmss-fffffff", CultureInfo.InvariantCulture) + "-" + Guid.NewGuid().ToString("N");
            string backup = Path.Combine(dir, id + ".json"), temp = c.Path + ".2plus-" + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                using (var file = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None)) { file.Write(bytes, 0, bytes.Length); file.Flush(true); }
                using (var file = new FileStream(backup, FileMode.CreateNew, FileAccess.Write, FileShare.None)) { file.Write(c.Bytes, 0, c.Bytes.Length); file.Flush(true); }
                if (Hash(File.ReadAllBytes(backup)) != c.Hash) throw new IOException("備份驗證失敗，未套用設定。");
                if (beforeCommit != null) beforeCommit();
                if (Hash(File.ReadAllBytes(c.Path)) != c.Hash) throw new IOException("設定已被其他程式更改，未覆蓋；請重新讀取。");
                File.Replace(temp, c.Path, null);
                string after = Hash(File.ReadAllBytes(c.Path));
                if (after != Hash(bytes)) throw new IOException("寫入後驗證失敗，原檔備份位於：" + backup);
                var result = new SaveResult { Changed = true, BackupPath = backup };
                try
                {
                    var entries = new Dictionary<string, string> { { "Version", "1.0.0" }, { "ConfigPath", c.Path }, { "Action", action }, { "BackupName", Path.GetFileName(backup) }, { "BeforeHash", c.Hash }, { "AfterHash", after } };
                    string receipt = "{\n" + string.Join(",\n", entries.Select(e => "  " + JsonReader.Quote(e.Key) + ": " + JsonReader.Quote(e.Value))) + "\n}";
                    File.WriteAllText(Path.Combine(dir, id + ".applied.json"), receipt, Utf8);
                }
                catch (IOException) { result.Warning = "設定已寫入，但還原索引無法儲存。請保留備份：" + backup; }
                catch (UnauthorizedAccessException) { result.Warning = "設定已寫入，但還原索引無法儲存。請保留備份：" + backup; }
                return result;
            }
            finally { if (File.Exists(temp)) File.Delete(temp); }
        }
        public static bool GameRunning(IEnumerable<ProcessInfo> processes)
        {
            foreach (var p in processes)
            {
                if (Regex.IsMatch(p.Name ?? "", @"\AProjectZomboid(32|64)?\.exe\z", RegexOptions.IgnoreCase)) return true;
                if (!Regex.IsMatch(p.Name ?? "", @"\Ajavaw?\.exe\z", RegexOptions.IgnoreCase)) continue;
                if (string.IsNullOrEmpty(p.CommandLine)) throw new IOException("無法確認某個 Java 程式是否為遊戲。請關閉僵毀及相關程式後再試。");
                if (Regex.IsMatch(p.CommandLine, @"zombie[/.](gameStates|GameWindow|network)|projectzomboid", RegexOptions.IgnoreCase)) return true;
            }
            return false;
        }
        public static string[] LibraryPaths(string vdf)
        {
            return Regex.Matches(vdf, "\"(?:path|[0-9]+)\"\\s*\"(?<path>(?:\\\\.|[^\"\\\\])*)\"")
                .Cast<Match>().Select(m => m.Groups["path"].Value.Replace("\\\\", "\\").Replace("\\\"", "\""))
                .Where(p => Regex.IsMatch(p, @"\A[a-zA-Z]:[\\/]") || p.StartsWith(@"\\", StringComparison.Ordinal)).ToArray();
        }
        public static string[] Candidates(IEnumerable<string> roots, IEnumerable<string> extras)
        {
            var libraries = new HashSet<string>(roots.Where(p => !string.IsNullOrWhiteSpace(p)), StringComparer.OrdinalIgnoreCase);
            foreach (string root in libraries.ToArray()) foreach (string relative in new[] { "steamapps/libraryfolders.vdf", "config/libraryfolders.vdf" }) try
            {
                string file = Path.Combine(root, relative); if (File.Exists(file)) foreach (string p in LibraryPaths(File.ReadAllText(file))) libraries.Add(p);
            } catch (IOException) { } catch (UnauthorizedAccessException) { }
            var folders = new List<string>(extras.Where(p => !string.IsNullOrWhiteSpace(p)));
            foreach (string library in libraries)
            {
                string common = Path.Combine(library, "steamapps/common"); folders.Add(Path.Combine(common, "ProjectZomboid"));
                try
                {
                    string file = Path.Combine(library, "steamapps/appmanifest_108600.acf");
                    if (!File.Exists(file)) continue;
                    var m = Regex.Match(File.ReadAllText(file), "\"installdir\"\\s*\"([^\"\\\\/]+)\"");
                    if (m.Success && m.Groups[1].Value != "." && m.Groups[1].Value != "..") folders.Add(Path.Combine(common, m.Groups[1].Value));
                } catch (IOException) { } catch (UnauthorizedAccessException) { }
            }
            // Return folders even when their JSON needs attention, so auto-discovery
            // can show the actual validation error instead of hiding the installation.
            return folders.Where(p => File.Exists(Path.Combine(p, "ProjectZomboid64.json"))).Select(Path.GetFullPath).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(p => p).ToArray();
        }
    }
}
