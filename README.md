# 💎 LuxRig - Autonomous Wealth Generation System

**Complete institutional-grade crypto trading platform with AI-powered automation**

![Status](https://img.shields.io/badge/status-production%20ready-brightgreen)
![Modules](https://img.shields.io/badge/modules-38%20core%20%2B%206%20utilities-blue)
![Lines](https://img.shields.io/badge/code-16%2C000%2B%20lines-orange)

---

## 🚀 Quick Start

### Prerequisites
- PowerShell 7.0+
- Exchange API keys (optional for demo mode)

### Installation

```powershell
# Clone repository
git clone https://github.com/yourusername/OPUS-DLX.git
cd OPUS-DLX

# Quick start (interactive setup)
./LuxRig/quick-start.ps1

# Or manual start
./LuxRig/master-control.ps1
```

### Demo Mode (No API Keys)
```powershell
./LuxRig/quick-start.ps1
# Select option 1 for Demo Mode
```

---

## 📊 Features

### Trading Infrastructure
- ✅ **5 Major Exchanges**: Coinbase, Binance, Kraken, Bybit, OKX
- ✅ **Spot + Futures**: Up to 125x leverage
- ✅ **Unified API**: Single interface for all exchanges
- ✅ **Real-time Data**: WebSocket streaming

### Automated Strategies
- ✅ **Scalper**: 100+ trades/day, 0.3% targets
- ✅ **Grid Bot**: Range trading automation
- ✅ **Swing Trader**: 1-7 day holds, 3-10% gains
- ✅ **DCA Bot**: Smart accumulation with dip buying
- ✅ **Arbitrage**: Cross-exchange + triangular
- ✅ **AI Predictor**: LSTM neural network predictions

### Risk Management
- ✅ **Kelly Criterion**: Optimal position sizing
- ✅ **VaR/CVaR**: Value at Risk calculations
- ✅ **Circuit Breakers**: Auto-stop on 5% daily loss
- ✅ **Liquidation Protection**: Never get rekt on futures
- ✅ **Portfolio Optimization**: Modern Portfolio Theory
- ✅ **Performance Analytics**: Sharpe, Sortino, Alpha/Beta

### Technical Analysis
- ✅ **100+ Indicators**: EMA, RSI, MACD, Bollinger, Stochastic, etc.
- ✅ **AI Pattern Recognition**: Head & Shoulders, Triangles, Candlesticks
- ✅ **Order Flow Analysis**: CVD, whale watching, absorption
- ✅ **Sentiment Aggregation**: Twitter, Reddit, Fear & Greed
- ✅ **On-Chain Metrics**: MVRV, NVT, exchange flows
- ✅ **Market Regime Detection**: Bull/Bear/Sideways classification

### Multi-Platform
- ✅ **Mobile**: React Native iOS/Android app
- ✅ **Watch**: Apple Watch complications
- ✅ **Desktop**: Electron terminal with multi-monitor support
- ✅ **Browser**: Chrome/Firefox extensions
- ✅ **CLI**: Professional command-line interface

### AI Systems
- ✅ **Reinforcement Learning**: Q-Learning, PPO agents
- ✅ **Ensemble Predictions**: Multi-model consensus
- ✅ **Strategy Portfolio**: Diversified allocation
- ✅ **Capital Optimization**: RL-based allocation
- ✅ **Model Tracking**: Performance monitoring, drift detection

---

## 🎯 Usage Examples

### Start Scalping Bot
```powershell
. ./LuxRig/Trading/Strategies/scalper-bot.ps1
Start-ScalpingBot -Exchange "Coinbase" -Symbol "BTC-USD" -Capital 10000
```

### Grid Trading
```powershell
. ./LuxRig/Trading/Strategies/grid-bot.ps1
Start-GridBot -Exchange "Binance" -Symbol "ETH-USD" -LowerBound 2000 -UpperBound 2200 -Levels 10
```

### Master Control Dashboard
```powershell
./LuxRig/master-control.ps1
# Interactive dashboard: start/stop strategies, monitor portfolio, view risk metrics
```

### CLI Trading
```powershell
./LuxRig/CLI/trader-cli.ps1
# Interactive REPL: buy, sell, portfolio, chart, indicators
```

---

## 📁 Project Structure

```
LuxRig/
├── Trading/
│   ├── Exchanges/          # 5 exchange integrations
│   ├── Strategies/         # 6 automated strategies
│   └── Risk/               # 4 risk management systems
├── Charts/
│   └── Analysis/           # Technical analysis, patterns, sentiment
├── AI/
│   ├── RL/                 # Reinforcement learning agents
│   ├── Ensemble/           # Multi-model systems
│   ├── Optimization/       # Capital allocation
│   └── Tracking/           # Performance monitoring
├── Mobile/                 # React Native apps
├── Desktop/                # Electron terminal
├── Extensions/             # Browser extensions
├── CLI/                    # Command-line interface
├── master-control.ps1      # Central dashboard
├── config-manager.ps1      # Configuration
├── health-monitor.ps1      # System monitoring
├── performance-tracker.ps1 # P&L tracking
├── logger.ps1              # Unified logging
└── quick-start.ps1         # Setup wizard
```

---

## ⚙️ Configuration

### Set Exchange API Keys
```powershell
. ./LuxRig/config-manager.ps1
Set-ExchangeAPI -Exchange "Coinbase" -ApiKey "your_key" -ApiSecret "your_secret"
```

### Enable Strategy
```powershell
Enable-Strategy -Strategy "Scalper" -Parameters @{ Capital = 10000; Timeframe = "1m" }
```

### Configure Risk Limits
```powershell
Set-Config -Section "Trading" -Key "MaxDailyLoss" -Value 0.05  # 5%
Set-Config -Section "Trading" -Key "MaxLeverage" -Value 10
```

---

## 📊 Monitoring

### Performance Tracking
```powershell
. ./LuxRig/performance-tracker.ps1
Get-PerformanceSummary -Days 30
Export-PerformanceReport -OutputPath "./reports/performance.html"
```

### System Health
```powershell
. ./LuxRig/health-monitor.ps1
Get-HealthReport
Start-HealthMonitor -IntervalSeconds 60
```

### Logs
```powershell
. ./LuxRig/logger.ps1
Get-Logs -Last 100
Get-Logs -Level "ERROR" -Last 50
```

---

## 🛡️ Risk Management

LuxRig includes institutional-grade risk controls:

- **Position Sizing**: Kelly Criterion with fractional Kelly (25%)
- **Stop Loss**: Automatic stop-loss on all positions
- **Daily Loss Limit**: 5% max (configurable)
- **Drawdown Monitoring**: 20% max drawdown alert
- **Liquidation Protection**: Real-time monitoring on futures
- **Correlation Analysis**: Avoid correlated positions
- **Circuit Breakers**: Halt trading on extreme conditions

---

## 📚 Documentation

- **Complete Guide**: [PHASE4_COMPLETE.md](./PHASE4_COMPLETE.md)
- **API Reference**: See individual module files
- **Architecture**: See project structure above
- **Examples**: See usage examples section

---

## 🧪 Testing

```powershell
# Backtest a strategy
. ./LuxRig/Desktop/BacktestStudio/backtester.ps1
Start-Backtest -Strategy $myStrategy -HistoricalData $candles -InitialCapital 10000
```

---

## ⚠️ Disclaimer

**Trading cryptocurrency carries significant risk. Use at your own risk.**

- This software is for educational and research purposes
- Past performance does not guarantee future results
- Never invest more than you can afford to lose
- Always test strategies in demo mode first
- Use proper risk management
- Not financial advice

---

## 📈 Stats

| Metric | Value |
|--------|-------|
| **Core Modules** | 38 |
| **Utilities** | 6 |
| **Total Lines** | 16,000+ |
| **Exchanges** | 5 |
| **Strategies** | 6 |
| **Indicators** | 100+ |
| **Platforms** | 5 |

---

## 🏆 Built With

- **PowerShell 7.0+** - Core logic
- **React Native** - Mobile app
- **Electron** - Desktop terminal
- **TypeScript/JavaScript** - Web components
- **Swift** - Apple Watch app

---

## 🎯 Key Capabilities

**Completed** ✅
- Phase 1-4: Core trading infrastructure (38 modules)
- Multi-exchange integration (5 exchanges)
- Automated strategies (6 strategies)
- AI/ML systems (8 modules)
- Multi-platform support (5 platforms)
- Risk management (4 systems)
- Technical analysis (100+ indicators)
- Utilities & monitoring (6 modules)

---

**Made with 💎 by the LuxRig Team**

*Autonomous wealth generation, simplified.*
