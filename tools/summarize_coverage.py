import glob
import os
import re

reports = glob.glob(r'C:\Users\BuiThanhQui\CPU-pineline\coverage\*\cov_report\files.html')
all_file_stats = {}

for rep in reports:
    tb_name = rep.split(os.sep)[-3]
    with open(rep, 'r', encoding='utf-8', errors='ignore') as f:
        html = f.read()
    rows = re.findall(r'<tr>(.*?)</tr>', html, re.DOTALL)
    for r in rows:
        cells = [re.sub(r'<[^>]+>', '', c).strip() for c in re.findall(r'<td[^>]*>(.*?)</td>', r, re.DOTALL)]
        if len(cells) >= 10:
            fn = os.path.basename(cells[1])
            if fn.endswith('.v') or fn.endswith('.sv'):
                if not fn.endswith('_tb.v') and fn != 'rv32i_sva.sv':
                    def parse_val(v):
                        try: return float(v)
                        except: return 0.0
                    stmt = parse_val(cells[4])
                    br = parse_val(cells[7])
                    cond = parse_val(cells[8])
                    togg = parse_val(cells[9])
                    if fn not in all_file_stats:
                        all_file_stats[fn] = []
                    all_file_stats[fn].append({'tb': tb_name, 'stmt': stmt, 'br': br, 'cond': cond, 'togg': togg})

print(f"{'Module File':<24} | {'Best Testbench':<22} | {'Stmt%':<7} | {'Branch%':<7} | {'Cond%':<7} | {'Toggle%':<7}")
print("-" * 88)
for fn in sorted(all_file_stats.keys()):
    stats = all_file_stats[fn]
    best = max(stats, key=lambda x: (x['stmt'], x['br'], x['togg']))
    b_tb = best['tb']
    b_s = best['stmt']
    b_b = best['br']
    b_c = best['cond']
    b_t = best['togg']
    print(f"{fn:<24} | {b_tb:<22} | {b_s:>6.2f}% | {b_b:>6.2f}% | {b_c:>6.2f}% | {b_t:>6.2f}%")
print("-" * 88)
