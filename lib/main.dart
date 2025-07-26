import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitcoin Wallet',
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: Color(0xFF1C1C1E),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF007AFF), // Changed from green to blue
          secondary: Color(0xFF007AFF),
          background: Color(0xFF1C1C1E),
          surface: Color(0xFF2C2C2E),
        ),
      ),
      home: WalletScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _addressController = TextEditingController();
  final Dio _dio = Dio();

  double _balance = 0.0;
  double _usdBalance = 0.0;
  bool _isLoading = false;
  bool _isTestnet = false;
  String _walletName = "Main Wallet";

  int _transactionCount = 0;
  double _totalReceived = 0.0;
  double _totalSent = 0.0;

  final String _sampleMainnetAddress = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
  final String _sampleTestnetAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

  @override
  void initState() {
    super.initState();
    // Load sample address on start
    _addressController.text = _sampleMainnetAddress;
    _checkBalance();
  }

  Future<void> _checkBalance() async {
    final address = _addressController.text.trim();

    if (address.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isTestnet) {
        // For testnet, use Blockstream API
        await _checkBlockstreamBalance(address);
      } else {
        // For mainnet, use Blockchain.info API (matches their explorer exactly)
        await _checkBlockchainInfoBalance(address);
      }

    } catch (e) {
      setState(() {
        _balance = 0.0;
        _usdBalance = 0.0;
        _transactionCount = 0;
        _totalReceived = 0.0;
        _totalSent = 0.0;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkBlockchainInfoBalance(String address) async {
    try {
      // Use the simple balance API first
      final balanceResponse = await _dio.get('https://blockchain.info/q/addressbalance/$address');
      final balanceSatoshis = int.parse(balanceResponse.data.toString());
      final balanceBTC = balanceSatoshis / 100000000.0;

      // Get detailed info for additional stats
      final detailResponse = await _dio.get('https://blockchain.info/rawaddr/$address?limit=0');
      final detailData = detailResponse.data;

      final totalReceivedBTC = (detailData['total_received'] ?? 0) / 100000000.0;
      final totalSentBTC = (detailData['total_sent'] ?? 0) / 100000000.0;
      final txCount = detailData['n_tx'] ?? 0;

      setState(() {
        _balance = balanceBTC;
        _usdBalance = balanceBTC * 67000; // Bitcoin price
        _totalReceived = totalReceivedBTC;
        _totalSent = totalSentBTC;
        _transactionCount = txCount;
        _isLoading = false;
      });

    } catch (e) {
      print('Blockchain.info API error: $e');
      // Fallback to Blockstream if Blockchain.info fails
      await _checkBlockstreamBalance(address);
    }
  }

  Future<void> _checkBlockstreamBalance(String address) async {
    try {
      final String baseUrl = _isTestnet
          ? 'https://blockstream.info/testnet/api'
          : 'https://blockstream.info/api';

      final response = await _dio.get('$baseUrl/address/$address');
      final data = response.data;
      final chainStats = data['chain_stats'] ?? {};
      final mempoolStats = data['mempool_stats'] ?? {};

      final int fundedSatoshis = (chainStats['funded_txo_sum'] ?? 0) +
          (mempoolStats['funded_txo_sum'] ?? 0);
      final int spentSatoshis = (chainStats['spent_txo_sum'] ?? 0) +
          (mempoolStats['spent_txo_sum'] ?? 0);
      final int balanceSatoshis = fundedSatoshis - spentSatoshis;

      final double balanceBTC = balanceSatoshis / 100000000.0;
      final double totalReceivedBTC = fundedSatoshis / 100000000.0;
      final double totalSentBTC = spentSatoshis / 100000000.0;

      final int txCount = (chainStats['tx_count'] ?? 0) +
          (mempoolStats['tx_count'] ?? 0);

      setState(() {
        _balance = balanceBTC;
        _usdBalance = balanceBTC * 67000; // Bitcoin price
        _totalReceived = totalReceivedBTC;
        _totalSent = totalSentBTC;
        _transactionCount = txCount;
        _isLoading = false;
      });

    } catch (e) {
      print('Blockstream API error: $e');
      setState(() {
        _balance = 0.0;
        _usdBalance = 0.0;
        _transactionCount = 0;
        _totalReceived = 0.0;
        _totalSent = 0.0;
        _isLoading = false;
      });
    }
  }

  void _showAddressInput() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Check Bitcoin Address',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _addressController,
              style: TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Bitcoin Address',
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Color(0xFF2C2C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(16),
              ),
              maxLines: 2,
              minLines: 1,
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _checkBalance();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF007AFF), // Changed to blue
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Check Balance',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    _addressController.text = _isTestnet ? _sampleTestnetAddress : _sampleMainnetAddress;
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2C2C2E),
                    padding: EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Icon(Icons.auto_awesome, color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showNFCScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'NFC Scanner',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Hold your device near an NFC tag',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 40),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color(0xFF007AFF),
                          width: 3,
                        ),
                      ),
                      child: Container(
                        margin: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFF007AFF).withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Container(
                          margin: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF007AFF).withOpacity(0.1),
                          ),
                          child: Icon(
                            Icons.nfc,
                            size: 80,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    Text(
                      'Scanning for NFC tags...',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Make sure NFC is enabled in your device settings',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _simulateNFCRead();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF007AFF),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Simulate NFC Read',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2C2C2E),
                    padding: EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _simulateNFCRead() {
    // Simulate NFC reading a Bitcoin address
    const mockNFCAddress = '3FpYfDGJSdkMAvZvCrwPHDqdmGqUkTsJys';
    _addressController.text = mockNFCAddress;

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.nfc, color: Colors.white),
            SizedBox(width: 8),
            Text('NFC tag read successfully!'),
          ],
        ),
        backgroundColor: Color(0xFF007AFF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    // Auto-check the balance
    _checkBalance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Header
                    _buildHeader(),

                    // Balance Section
                    _buildBalanceSection(),

                    // Action Buttons
                    _buildActionButtons(),

                    // Promo Card
                    _buildPromoCard(),

                    // Tabs and Content
                    _buildTabsSection(),
                  ],
                ),
              ),
            ),

            // Bottom Navigation - Fixed at bottom
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fullscreen, color: Colors.white, size: 20),
          ),
          Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _isTestnet = !_isTestnet;
                _walletName = _isTestnet ? "Test Wallet" : "Main Wallet";
              });
              _checkBalance();
            },
            child: Row(
              children: [
                Text(
                  _walletName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                if (_isTestnet)
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          Spacer(),
          GestureDetector(
            onTap: _showNFCScanner,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.nfc, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        children: [
          if (_isLoading)
            CircularProgressIndicator(color: Color(0xFF007AFF)) // Changed to blue
          else ...[
            Text(
              '\$${_usdBalance.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w300,
                letterSpacing: -2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${_balance.toStringAsFixed(8)} BTC (${_balance > 0 ? '+' : ''}0.00%)',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(Icons.arrow_upward, 'Send', false),
          _buildActionButton(Icons.copy, 'Receive', false),
          _buildActionButton(Icons.flash_on, 'Buy', true),
          _buildActionButton(Icons.account_balance, 'Sell', false),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, bool isHighlighted) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isHighlighted ? Color(0xFF007AFF) : Color(0xFF2C2C2E), // Changed highlighted color to blue
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPromoCard() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(Icons.currency_bitcoin, color: Colors.white, size: 30),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover and check',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Bitcoin addresses',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Explore now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              // Hide promo card
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsSection() {
    return Column(
      children: [
        // Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 5; i++)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: i == 1 ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == 1 ? Colors.white : Colors.grey[600],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        SizedBox(height: 20),

        // Tabs
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Crypto',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Container(
                height: 3,
                width: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF), // Changed to blue
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 24),
              Text(
                'NFTs',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Icon(Icons.tune, color: Colors.grey[400], size: 20),
            ],
          ),
        ),

        SizedBox(height: 40),

        // Empty State
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text(
                _balance > 0
                    ? 'Balance: ${_balance.toStringAsFixed(8)} BTC'
                    : 'Your wallet is empty.',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_transactionCount > 0) ...[
                SizedBox(height: 16),
                Text(
                  'Transactions: $_transactionCount',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 60),

        // Action Buttons
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showNFCScanner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF007AFF), // Changed to blue
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.nfc, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'NFC',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _addressController.text = _isTestnet ? _sampleTestnetAddress : _sampleMainnetAddress;
                    _checkBalance();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2C2C2E),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Try Sample Address',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40), // Extra padding at bottom
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(
          top: BorderSide(color: Color(0xFF2C2C2E), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.home, 'Home', true),
          _buildNavItem(Icons.trending_up, 'Trending', false),
          _buildNavItem(Icons.swap_horiz, 'Swap', false),
          _buildNavItem(Icons.account_balance_wallet, 'Earn', false),
          _buildNavItem(Icons.explore, 'Discover', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isActive ? Color(0xFF007AFF) : Colors.grey[400], // Changed active color to blue
          size: 24,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Color(0xFF007AFF) : Colors.grey[400], // Changed active color to blue
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
}