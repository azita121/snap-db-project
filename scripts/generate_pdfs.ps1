# Generate PDF documentation from Markdown sources
# Requires Pandoc: https://pandoc.org/installing.html
# Optional: LaTeX (MiKTeX) for better PDF formatting

$ErrorActionPreference = "Stop"
$DocsDir = Join-Path $PSScriptRoot "..\docs"

if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
    Write-Host "Pandoc not found. Install from https://pandoc.org/installing.html"
    Write-Host ""
    Write-Host "Alternative: Open docs/Proposal.md and docs/Documentation.md in VS Code"
    Write-Host "and use 'Markdown PDF' extension to export."
    exit 1
}

$pairs = @(
    @{ Input = "Proposal.md";       Output = "Proposal.pdf" },
    @{ Input = "Documentation.md";  Output = "Documentation.pdf" }
)

foreach ($pair in $pairs) {
    $inputPath  = Join-Path $DocsDir $pair.Input
    $outputPath = Join-Path $DocsDir $pair.Output

    if (-not (Test-Path $inputPath)) {
        Write-Warning "Missing: $inputPath"
        continue
    }

    pandoc $inputPath -o $outputPath `
        --pdf-engine=pdflatex `
        -V geometry:margin=1in `
        -V fontsize=11pt `
        --toc

    Write-Host "Generated: $outputPath"
}

Write-Host "Done."
