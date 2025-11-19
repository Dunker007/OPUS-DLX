// LuxRig Quick Trade Widget - iOS 14+ Home Screen Widget
import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

/**
 * iOS Home Screen Widget for quick trading
 * Features:
 * - Current portfolio value
 * - Top 3 holdings
 * - Quick action buttons
 * - Live price updates
 */

export const QuickTradeWidget = () => {
  const portfolioValue = 40000;
  const change24h = 5.2;

  const topHoldings = [
    { symbol: 'BTC', value: 25000, change: 5.2 },
    { symbol: 'ETH', value: 10000, change: 3.8 },
    { symbol: 'SOL', value: 5000, change: -2.1 }
  ];

  return (
    <View style={styles.widget}>
      <Text style={styles.title}>LuxRig Portfolio</Text>

      <View style={styles.totalContainer}>
        <Text style={styles.totalValue}>${portfolioValue.toLocaleString()}</Text>
        <Text style={styles.change}>
          {change24h > 0 ? '+' : ''}{change24h}% (24h)
        </Text>
      </View>

      <View style={styles.holdings}>
        {topHoldings.map((holding) => (
          <View key={holding.symbol} style={styles.holdingRow}>
            <Text style={styles.symbol}>{holding.symbol}</Text>
            <Text style={styles.value}>${holding.value.toLocaleString()}</Text>
            <Text style={holding.change > 0 ? styles.positive : styles.negative}>
              {holding.change > 0 ? '+' : ''}{holding.change}%
            </Text>
          </View>
        ))}
      </View>

      <View style={styles.actions}>
        <Text style={styles.actionButton}>📈 Buy</Text>
        <Text style={styles.actionButton}>📉 Sell</Text>
        <Text style={styles.actionButton}>📊 Chart</Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  widget: {
    flex: 1,
    backgroundColor: '#000',
    padding: 16,
    borderRadius: 20
  },
  title: {
    fontSize: 14,
    color: '#888',
    marginBottom: 8
  },
  totalContainer: {
    marginBottom: 12
  },
  totalValue: {
    fontSize: 28,
    color: '#0f0',
    fontWeight: 'bold'
  },
  change: {
    fontSize: 14,
    color: '#0f0'
  },
  holdings: {
    marginBottom: 12
  },
  holdingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginVertical: 4
  },
  symbol: {
    fontSize: 12,
    color: '#fff',
    fontWeight: 'bold',
    width: 50
  },
  value: {
    fontSize: 12,
    color: '#fff',
    flex: 1
  },
  positive: {
    fontSize: 12,
    color: '#0f0'
  },
  negative: {
    fontSize: 12,
    color: '#f00'
  },
  actions: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginTop: 8
  },
  actionButton: {
    fontSize: 16,
    color: '#0ff'
  }
});

// Widget configuration for iOS
export const widgetConfig = {
  kind: 'LuxRigQuickTrade',
  supportedFamilies: ['small', 'medium'],
  updateInterval: 300, // 5 minutes
  deepLinkURL: 'luxrig://quicktrade'
};
