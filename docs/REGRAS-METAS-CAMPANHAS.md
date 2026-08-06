# Regras de Metas (pagamento/bônus) e Campanhas — mapa completo

> Extraído **do código** do app de Metas (`faturamento/index.html`), fiel à lógica atual.
> Serve de especificação para reconstruir tudo em tabelas no banco do RH.
> Valores em **R$** são padrões — **editáveis por setor** pela engrenagem do RH.

---

## 0. Conceitos-base

- **Dois setores**: `EXTERNO` e `INTERNO`. Regras iguais dentro do setor; por pessoa muda só o "participa ou não" de cada meta.
- **Chave hoje**: nome do vendedor (frágil). **No rebuild: usar o `código` do vendedor.**
- **Dado de cada vendedor/mês**: `objFat, vendido, objMix, mixVend, carteira, positivados, positObj, areceber, vencido, transito, recebido, marcaVendas{MARCA:{vendas,peso,produtos,itens,positivados}}`.
- **Mês fechado** (`status='fechado'`): trava o mês; **os valores de bônus só aparecem quando o mês está fechado** (durante o mês mostra "no fechamento").

---

## 1. Metas de pagamento — os 4 indicadores (por vendedor)

Cada vendedor pode ganhar bônus por 4 metas independentes. **Padrão de valor por meta batida:**

| Meta | Valor padrão | Como bate |
|---|---|---|
| **Faturamento** | R$ 120 | `vendido ≥ objFat` (fatPct = vendido/objFat ≥ 1) |
| **Mix** | R$ 100 | `mixVend ≥ objMix` (produtos diferentes) |
| **Positivação** | R$ 100 | `positPct ≥ 90%` |
| **Inadimplência** | R$ 200 | inadimplência **abaixo** da meta |

### Positivação — base por setor
- **Externo**: base = `carteira` de clientes → `positPct = positivados / carteira`. Bate se ≥ **90%**.
- **Interno**: base = `positObj` (meta de vendas) → `positPct = positivados / positObj`. Bate se ≥ **90%**.

### Inadimplência — fórmula única
```
inadimplência(%) = max(0, (vencido − transito)) / areceber × 100
```
- `transito` = boletos vencidos nos **últimos 3 dias** (não conta como calote).
- **Externo**: **individual** — bate se `inad < meta` (padrão **10%**).
- **Interno**: bate **só se o GRUPO interno (sem o Delivery) inteiro** ficar abaixo da meta (padrão **5%**). Se o grupo bate, **todos os internos** ganham os R$200.

### Regra automática de carteira (posit + inad)
```
carteiraOk = carteira > minCli(30)  E  areceber > minCart(R$ 20.000)
```
- Quem **não** tem carteira suficiente **não participa** de Positivação nem Inadimplência — **a não ser** que o RH marque a pessoa explicitamente.

### Participação por pessoa (RH liga/desliga)
- Cada indicador (`fat/mix/posit/inad`) pode ser **desligado por pessoa** pelo RH (padrão: participa).
- Posit/Inad ainda exigem `carteiraOk` (salvo marcação explícita).

### Forma de pagamento (por meta, por setor)
- Cada meta pode pagar em **R$ fixo** ou **% de uma base** (base = `recebido`, senão `vendido`). Hoje todas em **R$**.

### Peso
- **Indicador de controle apenas — NÃO conta no bônus.** Soma o peso (kg) de todas as marcas + valor médio por kg.

### Tendência
- Projeção informativa: `tend = vendido / diasTrab × diasUteis`. Não paga nada.

---

## 2. Bônus de marca (fornecedor)

- Estrutura: `{marca, criterio: PESO|FAT, escopo: EXTERNO|INTERNO|TODOS, valorSetor{EXTERNO,INTERNO}, metas{NOME:alvoIndividual}}`.
- A meta de **cada** vendedor é informada **manualmente** (não é dividida automaticamente).
- **Participa quem tem meta > 0.** Quem **bater a sua meta** ganha o **valor do fornecedor do seu setor** (não divide entre os que bateram).
- Valores-fornecedor padrão: **HARALD 50 · MAVALERIO 80 · ADIMIX 40 · FINISSIMO 60**.
- O bônus de marca **soma** ao bônus dos 4 indicadores.

---

## 3. Comissão de salário (separada do bônus)

Cada vendedor tem um modo de comissão:

### Individual
- `comissao = pct% × base`, base = **recebido** (se informado e > 0), senão **vendido**.
- Se base=recebido mas ainda não veio → marcado como **provisório** (usa vendido por enquanto).

### Equipe (ex.: equipe interna — `comMode='equipe'`)
- `metaSum = Σ objFat do time` · `vendSum = Σ vendido do time`.
- **Atingiu** se `vendSum ≥ metaSum × 90%`.
- `pct = atingiu ? 0,5% : 0,3%` (escalonado).
- `base = Σ recebido do time` (senão vendido). `total = pct% × base`. **Dividido igualmente** entre os membros (`porCabeça = total / nº membros`).

---

## 4. Supervisores

### GENIVALDO — Supervisor EXTERNO (comissão %)
```
comissão = base × pctTotal%
pctTotal  = basePct(0,8%) + Σ p.p. dos índices da EQUIPE externa batidos, com TETO ppMax = 0,3 p.p.
```
- p.p. por índice (da **equipe**): Fat **+0,10** · Inad **+0,10** · Mix **+0,05** · Posit **+0,05**.
- `base` = **recebimento externo** (informado, senão soma dos recebidos, senão faturamento).
- Índice "bate" no nível de **EQUIPE externa**: Fat (Σvendido≥Σmeta), Mix (mixReal≥mixObj), Posit (Σposit/Σbase≥90%), Inad (equipe externa < 10%).

### TATIANA — Supervisora INTERNA (R$ por índice)
- Ganha **R$ 100 por índice** do **resultado da EQUIPE interna** batido (valIdx: fat/mix/posit/inad = R$100 cada).
- Mesma lógica de "geral interno batido"; base = recebimento interno.

---

## 5. Agregados de equipe (para supervisor e painéis)

- `teamAgg(setor)`: soma objFat, vendido, positivados, positBase (ext=carteira / int=positObj), areceber, vencido, transito, recebido; `inadPct` da equipe.
- `supHits(setor)`: Fat = vendido≥meta · Mix = mixReal≥mixObj · Posit = Σposit/base≥90% · Inad = equipe < meta.
- `teamInadAgg`: inadimplência agregada = `max(0,(Σvencido−Σtransito))/Σareceber`. `excludeDelivery` tira o Delivery (usado no grupo interno).

---

## 6. Campanhas (fornecedor)

### Estrutura
`{marcas[], ini, fim, minPart, criterio | criterios[] (multi), premio, metasInd{}, porMeta, marcos[]}`
- **Período** `ini..fim`; a campanha só aparece nos meses do período.
- **Multi-critério**: cada critério vira uma "sub-campanha" com seu próprio prêmio.

### Critérios de ranking (`campValor`)
| Critério | O que mede (soma das marcas da campanha) |
|---|---|
| **FAT** | faturamento (R$) |
| **PESO** | peso (kg) |
| **CRESC** | crescimento % = (atual − anterior) / anterior × 100 |
| **PROD** | produtos diferentes |
| **QTD** | itens vendidos (unidades) |
| **POSIT** | positivação (presença da marca nas vendas) |
| **MIX** | nº de marcas movimentadas |
| **METALVO / porMeta** | % da **meta individual** (`valor / metaInd × 100`) |

### Ranking (`campRank`)
1. Filtra por **escopo** (EXTERNO / INTERNO / geral).
2. **Exclui supervisores** e cards "Férias/Extra" (não concorrem).
3. Mantém quem tem `valor > 0` **e** `valor ≥ minPart`.
4. Ordena **decrescente** pelo valor.

### "Mínimo para participar" (`minPart`)
- **Piso de valor pra entrar no ranking.** Quem fica abaixo do mínimo **não concorre ao prêmio**.

### Prêmio (`campPremioPos`)
- **PÓDIO**: `podio[pos-1]` para cada posição do pódio (1º, 2º, 3º…).
- **META**: se `valor ≥ metaVal` → paga `premioVal` (bônus por atingir alvo, sem ranking).
- **COMBINADO**: paga o prêmio do pódio **só se** também `valor ≥ metaVal`.

### Mês de referência da campanha
- A campanha lê os vendedores do **melhor mês com dados** da(s) marca(s) no período (`campBestMes`) — não zera se o mês atual ainda não tem venda.

---

## 7. O que reaproveitar IDÊNTICO no rebuild

Esta é a parte de valor que **não muda**: a **lógica dos itens 1–6**. No banco do RH vira:
- `regras_comissao` (por setor): bônus por meta, positAlvo, inadMeta, minCli, minCart, forma de pagamento, regras de supervisor.
- `marcas_bonus` (valor por fornecedor/setor + metas individuais).
- `campanhas` + `campanha_criterios` + `campanha_premios`.
- O **motor** (metasCalc / campRank) é recalculado por consulta, amarrando tudo pelo **código do vendedor**.
