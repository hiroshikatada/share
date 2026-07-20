# v1.5.0-015 Boss SQL Stress Test

## 実行

```bash
node test/test_v1_5_0_015.js
```

ZIP単体ではStatic Validationが動作し、SQL規模・必須構文・CTE数・JOIN数を検証します。

既存のLineage Engineへ接続する場合は、CommonJSモジュールのパスを指定します。

### PowerShell

```powershell
$env:LINEAGE_ENGINE_MODULE="C:\path\to\project\src\index.js"
node test/test_v1_5_0_015.js
```

### macOS / Linux

```bash
LINEAGE_ENGINE_MODULE=/path/to/project/src/index.js node test/test_v1_5_0_015.js
```

モジュールは `analyzeSql`、`analyze`、`parseAndResolve`、`run` のいずれかをexportしてください。`tokenize` は任意です。

## Golden初期生成

```bash
UPDATE_GOLDEN=1 node test/test_v1_5_0_015.js
```

エンジン接続時はGolden比較、Lineage深度、出力列数、中央値、P95、ヒープ増分も検証します。
