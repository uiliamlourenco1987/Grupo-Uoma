# Leitores dos relatórios padronizados (validados nos arquivos reais).
import re, csv, html, io

def _text(path):
    """Lê o arquivo tentando utf-8 (exportado do Google) e latin-1 (original)."""
    data = open(path, "rb").read()
    for enc in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            continue
    return data.decode("latin-1", errors="replace")

def num(s):
    s = (s or '').strip().strip('"').strip()
    if s in ('', '-'):
        return 0.0
    neg = s.startswith('-'); s = s.lstrip('-')
    if '.' in s and ',' in s:
        s = s.replace('.', '').replace(',', '.')
    elif ',' in s:
        s = s.replace(',', '.')
    try:
        v = float(s)
    except ValueError:
        v = 0.0
    return -v if neg else v

def parse_desempenho(path):
    """relatorio_de_desempenho.csv -> lista de vendedores com os KPIs do mês."""
    rows = []
    rd = csv.reader(io.StringIO(_text(path)), delimiter=';')
    head = [h.strip().strip('"') for h in next(rd)]
    if True:
        for r in rd:
            if not r or not any(x.strip().strip('"') for x in r):
                continue
            d = dict(zip(head, [x.strip().strip('"') for x in r]))
            if not d.get('VENDEDOR'):
                continue
            rows.append({
                'codigo': d.get('CODIGO'), 'vendedor': d.get('VENDEDOR'),
                'vendas': num(d.get('VENDAS')), 'positivacao': int(num(d.get('POSITIVACAO'))),
                'peso': num(d.get('PESO')), 'mix': int(num(d.get('MIXPRODUTO'))),
                'carteira': int(num(d.get('CARTEIRACLIENTES'))), 'atendidos': int(num(d.get('CLIENTESATENDIDOS'))),
                'areceber': num(d.get('ARECEBER')), 'vencido': num(d.get('TOTALVENCIDOS')),
                'transito': num(d.get('TOTALTRANSITO')), 'inad': num(d.get('INADIMPLENCIA')),
            })
    return rows

def parse_marcas(path):
    """vendas_marca_peso.csv -> {vendedor: {marca: {kilos, vendas}}}"""
    agg = {}
    rd = csv.reader(io.StringIO(_text(path)), delimiter=';')
    next(rd)
    if True:
        for r in rd:
            if not r or not any(x.strip().strip('"') for x in r):
                continue
            marca = r[1].strip().strip('"'); nome = r[3].strip().strip('"')
            agg.setdefault(nome, {}).setdefault(marca, {'kilos': 0.0, 'vendas': 0.0})
            agg[nome][marca]['kilos'] += num(r[4]); agg[nome][marca]['vendas'] += num(r[6])
    return agg

def parse_ven430(path):
    """VEN430LA_xxx.html -> {vendedor: {produtos, itens, valor}} + periodo."""
    raw = _text(path)
    m = re.search(r'<PRE>(.*?)</PRE>', raw, re.S | re.I)
    txt = html.unescape(m.group(1)) if m else raw
    per = re.search(r'PER\S*ODO DE\s*(\d{2}/\d{2}/\d{4})\s*A\s*(\d{2}/\d{2}/\d{4})', txt)
    vend = None; out = {}
    for line in txt.splitlines():
        mv = re.search(r'VENDEDOR:\s*(\d+)-(.+?)\s*$', line)
        if mv:
            vend = mv.group(2).strip(); out.setdefault(vend, {'produtos': 0, 'itens': 0.0, 'valor': 0.0}); continue
        mt = re.search(r'TOTAL DO VENDEDOR:\s*\((\d+)\)\s+([\d\.,\-]+)\s+([\d\.,\-]+)', line)
        if mt and vend:
            out[vend] = {'produtos': int(mt.group(1)), 'itens': num(mt.group(2)), 'valor': num(mt.group(3))}
    return {'periodo': (per.group(1), per.group(2)) if per else None, 'vendedores': out}
