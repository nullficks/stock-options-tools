# Stock Options Lab

A web application for visualizing stock options strategies using Yahoo Finance data.

## Features

- **Covered Call Analysis**: View potential returns and downside protection for covered call strategies
- **Vertical Spreads**: Analyze bull/bear spreads with risk/reward visualization
- **Interactive Charts**: ECharts-powered scatter plots showing strategy metrics
- **Real-time Data**: Fetches live options data from Yahoo Finance

## Usage

1. Enter a stock ticker (e.g., AAPL, TSLA, NVDA)
2. Click "Load Options" to fetch data
3. View interactive charts and detailed tables

## Technology Stack

- **Frontend**: Dart compiled to JavaScript
- **Styling**: Bootstrap 5, custom CSS
- **Charts**: Apache ECharts
- **Tables**: ag-Grid
- **Data**: Yahoo Finance API

## Development

```bash
# Install dependencies
dart pub get

# Build for web
dart compile web/main.dart -o web/main.dart.js
```

## Deployment

Automatic deployment via GitHub Actions to GitHub Pages on every push to main branch.

## Disclaimer

This tool is for educational purposes only. Not financial advice. Options trading involves significant risk.
