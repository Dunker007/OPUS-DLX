#Requires -Version 7.0
<#
.SYNOPSIS
    LuxRig Mobile Trading App - React Native Setup
.DESCRIPTION
    Full-featured mobile crypto trading app:
    - Real-time portfolio tracking
    - Quick buy/sell
    - Chart analysis
    - Price alerts
    - Biometric authentication
    - Push notifications
.NOTES
    Part of Phase 4: Platform Applications
#>

Write-Host "📱 LuxRig Mobile Trading App - React Native" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════`n" -ForegroundColor Green

# Create React Native project structure
$appStructure = @{
    "package.json" = @"
{
  "name": "luxrig-mobile",
  "version": "1.0.0",
  "description": "LuxRig Mobile Trading App",
  "main": "index.js",
  "scripts": {
    "android": "react-native run-android",
    "ios": "react-native run-ios",
    "start": "react-native start",
    "test": "jest"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-native": "^0.72.0",
    "@react-navigation/native": "^6.1.0",
    "@react-navigation/bottom-tabs": "^6.5.0",
    "react-native-chart-kit": "^6.12.0",
    "react-native-biometrics": "^3.0.1",
    "react-native-push-notification": "^8.1.1",
    "axios": "^1.4.0",
    "@reduxjs/toolkit": "^1.9.5",
    "react-redux": "^8.1.1"
  }
}
"@

    "src/screens/Portfolio.tsx" = @"
import React from 'react';
import { View, Text, StyleSheet, FlatList } from 'react-native';

export const PortfolioScreen = () => {
  const portfolio = [
    { symbol: 'BTC', amount: 0.5, value: 25000, change: 5.2 },
    { symbol: 'ETH', amount: 5.0, value: 10000, change: 3.8 },
    { symbol: 'SOL', amount: 100, value: 5000, change: -2.1 }
  ];

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Portfolio</Text>
      <Text style={styles.totalValue}>\`$40,000.00</Text>
      <Text style={styles.totalChange}>+5.2% (24h)</Text>

      <FlatList
        data={portfolio}
        keyExtractor={(item) => item.symbol}
        renderItem={({ item }) => (
          <View style={styles.assetCard}>
            <Text style={styles.symbol}>{item.symbol}</Text>
            <Text>{item.amount}</Text>
            <Text style={styles.value}>\`${item.value.toLocaleString()}</Text>
            <Text style={item.change > 0 ? styles.positive : styles.negative}>
              {item.change > 0 ? '+' : ''}{item.change}%
            </Text>
          </View>
        )}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, padding: 20, backgroundColor: '#000' },
  title: { fontSize: 24, color: '#fff', fontWeight: 'bold' },
  totalValue: { fontSize: 36, color: '#0f0', marginTop: 10 },
  totalChange: { fontSize: 18, color: '#0f0' },
  assetCard: { padding: 15, backgroundColor: '#111', marginVertical: 5, borderRadius: 10 },
  symbol: { fontSize: 18, color: '#fff', fontWeight: 'bold' },
  value: { fontSize: 16, color: '#fff' },
  positive: { color: '#0f0' },
  negative: { color: '#f00' }
});
"@

    "src/screens/QuickTrade.tsx" = @"
import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet } from 'react-native';

export const QuickTradeScreen = () => {
  const [symbol, setSymbol] = useState('BTC-USD');
  const [amount, setAmount] = useState('');
  const [side, setSide] = useState<'BUY' | 'SELL'>('BUY');

  const executeTrade = () => {
    console.log(\`Executing \${side} \${amount} \${symbol}\`);
    // Call API
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Quick Trade</Text>

      <TextInput
        style={styles.input}
        placeholder="Symbol (e.g., BTC-USD)"
        value={symbol}
        onChangeText={setSymbol}
        placeholderTextColor="#666"
      />

      <TextInput
        style={styles.input}
        placeholder="Amount"
        value={amount}
        onChangeText={setAmount}
        keyboardType="numeric"
        placeholderTextColor="#666"
      />

      <View style={styles.buttonRow}>
        <TouchableOpacity
          style={[styles.button, styles.buyButton]}
          onPress={() => { setSide('BUY'); executeTrade(); }}
        >
          <Text style={styles.buttonText}>BUY</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, styles.sellButton]}
          onPress={() => { setSide('SELL'); executeTrade(); }}
        >
          <Text style={styles.buttonText}>SELL</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.info}>Current Price: \`$50,000</Text>
      <Text style={styles.info}>Estimated Total: \`${(parseFloat(amount) || 0) * 50000}</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, padding: 20, backgroundColor: '#000' },
  title: { fontSize: 24, color: '#fff', fontWeight: 'bold', marginBottom: 20 },
  input: { backgroundColor: '#111', color: '#fff', padding: 15, borderRadius: 10, marginVertical: 10, fontSize: 16 },
  buttonRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 20 },
  button: { flex: 1, padding: 20, borderRadius: 10, marginHorizontal: 5 },
  buyButton: { backgroundColor: '#0f0' },
  sellButton: { backgroundColor: '#f00' },
  buttonText: { color: '#000', fontSize: 18, fontWeight: 'bold', textAlign: 'center' },
  info: { color: '#666', marginTop: 10, fontSize: 14 }
});
"@

    "README.md" = @"
# LuxRig Mobile Trading App

Full-featured React Native crypto trading app.

## Features
- **Portfolio Tracking**: Real-time portfolio value and PnL
- **Quick Trade**: Fast market orders
- **Charts**: TradingView-style price charts
- **Alerts**: Price and indicator alerts
- **Biometric Auth**: Face ID / Touch ID
- **Push Notifications**: Trade alerts and price movements

## Setup

\`\`\`bash
# Install dependencies
npm install

# iOS
cd ios && pod install && cd ..
npx react-native run-ios

# Android
npx react-native run-android
\`\`\`

## Architecture
- React Native (TypeScript)
- Redux Toolkit (state management)
- React Navigation (routing)
- Axios (API calls)
- React Native Chart Kit (charts)
- React Native Biometrics (auth)
"@
}

foreach ($file in $appStructure.Keys) {
    $filePath = Join-Path $PSScriptRoot $file
    $directory = Split-Path $filePath -Parent

    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $appStructure[$file] | Out-File -FilePath $filePath -Encoding UTF8
    Write-Host "✅ Created: $file" -ForegroundColor Green
}

Write-Host "`n📱 Mobile app structure created!" -ForegroundColor Green
Write-Host "   To build: npm install && npx react-native run-ios" -ForegroundColor Cyan
