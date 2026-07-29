# 生成独立 HTML：内嵌 TSX 源码 + Babel 浏览器端编译渲染（用完可删）
import io

tsx_path = '/Users/xialuyao/Documents/魔兽世界code/鸟德/02-输出循环/DruidBalanceRailgunFlowchart.canvas.tsx'
with io.open(tsx_path, 'r', encoding='utf-8') as f:
    src = f.read()

# 去掉 import 行，导出改为普通函数
lines = []
for line in src.split('\n'):
    if line.startswith('import '):
        continue
    if line.startswith('export default function'):
        line = line.replace('export default function', 'function')
    lines.append(line)
src = '\n'.join(lines)

html = u'''<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<title>轨道炮鸟德 V2 流程图</title>
<script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
<script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
<style>body { margin: 0; }</style>
</head>
<body>
<div id="root"></div>
<script type="text/plain" id="tsx-src">
// ─── SDK 组件简化实现 ───
const Stack = ({ children, gap = 8, style = {} }) => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: gap + 'px', ...style }}>{children}</div>
);
const Grid = ({ children, columns = 2, gap = 8, style = {} }) => (
  <div style={{ display: 'grid', gridTemplateColumns: `repeat(${columns}, 1fr)`, gap: gap + 'px', ...style }}>{children}</div>
);
const H1 = ({ children, style = {} }) => <h1 style={style}>{children}</h1>;
const H2 = ({ children, style = {} }) => <h2 style={style}>{children}</h2>;
const Text = ({ children, size, style = {} }) => <p style={{ margin: 0, fontSize: size === 'small' ? '12px' : '14px', ...style }}>{children}</p>;
const Divider = () => <hr style={{ border: 'none', borderTop: '1px solid #e5e7eb', margin: '12px 0' }} />;

__COMPONENT_SRC__

ReactDOM.createRoot(document.getElementById('root')).render(<DruidBalanceRailgunFlowchart />);
</script>
<script>
const raw = document.getElementById('tsx-src').textContent;
const out = Babel.transform(raw, {
  filename: 'flowchart.tsx',
  presets: ['typescript', ['react', { runtime: 'classic' }]],
});
eval(out.code);
</script>
</body>
</html>
'''

html = html.replace('__COMPONENT_SRC__', src)

out_path = '/Users/xialuyao/Documents/魔兽世界code/鸟德/02-输出循环/流程图导出.html'
with io.open(out_path, 'w', encoding='utf-8') as f:
    f.write(html)

print('OK: ' + out_path)
