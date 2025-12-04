import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class ExplorePage extends StatelessWidget {
  const ExplorePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Artık burada yeni bir MaterialApp oluşturmuyoruz,
    // direkt olarak ekranı döndürüyoruz.
    return const StreetRiskScreen();
  }
}

class StreetData {
  final String city;
  final String street;
  final int totalAccidents;
  final double zScore;
  final String riskLevel;
  final int totalClusterNumber;
  final String coordinateTuple;

  StreetData({
    required this.city,
    required this.street,
    required this.totalAccidents,
    required this.zScore,
    required this.riskLevel,
    required this.totalClusterNumber,
    required this.coordinateTuple,
  });

  factory StreetData.fromJson(Map<String, dynamic> json) {
    return StreetData(
      city: json['City'] ?? '',
      street: json['Street'] ?? '',
      totalAccidents: json['Total_Accidents'] ?? 0,
      zScore: (json['Z_score'] ?? 0).toDouble(),
      riskLevel: json['Risk_level'] ?? 'Unknown',
      totalClusterNumber: json['Total_Cluster_Number_DBSCAN'] ?? 0,
      coordinateTuple: json['Coordinate_Tuple'] ?? '',
    );
  }

  String get displayName => '$street, $city';
}

class StreetRiskScreen extends StatefulWidget {
  const StreetRiskScreen({Key? key}) : super(key: key);

  @override
  State<StreetRiskScreen> createState() => _StreetRiskScreenState();
}

class _StreetRiskScreenState extends State<StreetRiskScreen> {
  List<StreetData> streetData = [];
  StreetData? mostDangerous;
  StreetData? safest;
  bool isLoading = true;

  /// Dark mode, global Theme üzerinden okunuyor
  bool _isDarkMode = false;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/City_Level_Street_Risk.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      setState(() {
        streetData =
            jsonData.map((item) => StreetData.fromJson(item)).toList();

        if (streetData.isNotEmpty) {
          streetData
              .sort((a, b) => b.totalAccidents.compareTo(a.totalAccidents));
          mostDangerous = streetData.first;
          safest = streetData.last;
        }

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading data: $e');
    }
  }

  void _showRiskAlert(StreetData street) {
    final riskColor = _getRiskAlertColor(street.riskLevel);
    final icon = _getRiskIcon(street.riskLevel);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: riskColor, width: 3),
          ),
          title: Row(
            children: [
              Icon(icon, color: riskColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  street.riskLevel,
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAlertInfoRow('Street', street.street, Icons.route),
              const SizedBox(height: 12),
              _buildAlertInfoRow('City', street.city, Icons.location_city),
              const SizedBox(height: 12),
              _buildAlertInfoRow(
                  'Total Accidents',
                  '${street.totalAccidents}',
                  Icons.car_crash),
              const SizedBox(height: 12),
              _buildAlertInfoRow('Risk Score (Z)',
                  street.zScore.toStringAsFixed(2), Icons.analytics),
              const SizedBox(height: 12),
              _buildAlertInfoRow('Clusters',
                  '${street.totalClusterNumber}', Icons.scatter_plot),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: riskColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Close',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlertInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _secondaryTextColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: _secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: _textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getRiskAlertColor(String riskLevel) {
    switch (riskLevel) {
      case 'High Risk':
        return Colors.red.shade600;
      case 'Medium Risk':
        return Colors.orange.shade600;
      case 'Low Risk':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel) {
      case 'High Risk':
        return Icons.dangerous;
      case 'Medium Risk':
        return Icons.warning_amber_rounded;
      case 'Low Risk':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color getRiskColor(String riskLevel) {
    if (_isDarkMode) {
      switch (riskLevel) {
        case 'High Risk':
          return Colors.red.shade900;
        case 'Medium Risk':
          return Colors.orange.shade900;
        case 'Low Risk':
          return Colors.green.shade900;
        default:
          return Colors.grey.shade800;
      }
    } else {
      switch (riskLevel) {
        case 'High Risk':
          return Colors.red.shade100;
        case 'Medium Risk':
          return Colors.orange.shade100;
        case 'Low Risk':
          return Colors.green.shade100;
        default:
          return Colors.grey.shade100;
      }
    }
  }

  Color getRiskBorderColor(String riskLevel) {
    if (_isDarkMode) {
      switch (riskLevel) {
        case 'High Risk':
          return Colors.red.shade700;
        case 'Medium Risk':
          return Colors.orange.shade700;
        case 'Low Risk':
          return Colors.green.shade700;
        default:
          return Colors.grey.shade600;
      }
    } else {
      switch (riskLevel) {
        case 'High Risk':
          return Colors.red.shade300;
        case 'Medium Risk':
          return Colors.orange.shade300;
        case 'Low Risk':
          return Colors.green.shade300;
        default:
          return Colors.grey.shade300;
      }
    }
  }

  Color getRiskTextColor(String riskLevel) {
    if (_isDarkMode) {
      switch (riskLevel) {
        case 'High Risk':
          return Colors.red.shade300;
        case 'Medium Risk':
          return Colors.orange.shade300;
        case 'Low Risk':
          return Colors.green.shade300;
        default:
          return Colors.grey.shade400;
      }
    } else {
      switch (riskLevel) {
        case 'High Risk':
          return Colors.red.shade700;
        case 'Medium Risk':
          return Colors.orange.shade800;
        case 'Low Risk':
          return Colors.green.shade700;
        default:
          return Colors.grey.shade700;
      }
    }
  }

  Color get _backgroundColor =>
      _isDarkMode ? const Color(0xFF121212) : Colors.white;
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _secondaryTextColor =>
      _isDarkMode ? Colors.grey[400]! : Colors.grey.shade600;
  Color get _borderColor =>
      _isDarkMode ? Colors.grey[700]! : Colors.grey.shade300;

  @override
  Widget build(BuildContext context) {
    // 🔹 Dark mode bilgisini global temadan alıyoruz
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: _isDarkMode ? Colors.blue.shade300 : Colors.blue,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          _isDarkMode ? const Color(0xFF1a237e) : Colors.blue.shade50,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isDarkMode
                ? [const Color(0xFF1a237e), const Color(0xFF0d47a1)]
                : [Colors.blue.shade50, Colors.indigo.shade100],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  'Street Safety Dashboard',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(child: _buildDangerousCard()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSafestCard()),
                  ],
                ),
                const SizedBox(height: 30),
                _buildAutocompleteSearch(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteSearch() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Search by Street Name',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type at least 3 characters to see suggestions',
            style: TextStyle(
              fontSize: 14,
              color: _secondaryTextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Autocomplete<StreetData>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              final query = textEditingValue.text.trim().toLowerCase();

              if (query.length < 3) {
                return const Iterable<StreetData>.empty();
              }

              return streetData.where((street) {
                return street.street.toLowerCase().contains(query) ||
                    street.city.toLowerCase().contains(query);
              });
            },
            displayStringForOption: (StreetData option) =>
                option.displayName,
            onSelected: (StreetData selection) {
              _showRiskAlert(selection);
            },
            fieldViewBuilder: (BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted) {
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                style: TextStyle(color: _textColor),
                decoration: InputDecoration(
                  hintText: 'Enter a street name...',
                  hintStyle: TextStyle(color: _secondaryTextColor),
                  prefixIcon: Icon(
                    Icons.search,
                    color:
                        _isDarkMode ? Colors.blue.shade300 : Colors.blue,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _borderColor, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _borderColor, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isDarkMode
                          ? Colors.blue.shade300
                          : Colors.blue,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                ),
              );
            },
            optionsViewBuilder: (BuildContext context,
                AutocompleteOnSelected<StreetData> onSelected,
                Iterable<StreetData> options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: _cardColor,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder:
                          (BuildContext context, int index) {
                        final StreetData option =
                            options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            margin:
                                const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: getRiskColor(option.riskLevel),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    getRiskBorderColor(option.riskLevel),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getRiskIcon(option.riskLevel),
                                  color:
                                      getRiskTextColor(option.riskLevel),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.street,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight.w600,
                                          color: _isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${option.city} • ${option.riskLevel}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: getRiskTextColor(
                                              option.riskLevel),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: getRiskTextColor(
                                            option.riskLevel)
                                        .withOpacity(0.2),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${option.totalAccidents}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: getRiskTextColor(
                                          option.riskLevel),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDangerousCard() {
    if (mostDangerous == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.red.shade900
            : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDarkMode
              ? Colors.red.shade700
              : Colors.red.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(_isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Most Dangerous Street',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _isDarkMode
                  ? Colors.red.shade200
                  : Colors.red.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            mostDangerous!.street,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _isDarkMode
                  ? Colors.red.shade100
                  : Colors.red.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            '${mostDangerous!.totalAccidents} accidents',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _isDarkMode
                  ? Colors.red.shade200
                  : Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 15),
          Icon(
            Icons.warning_amber_rounded,
            color: _isDarkMode
                ? Colors.red.shade300
                : Colors.red.shade600,
            size: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildSafestCard() {
    if (safest == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.green.shade900
            : Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDarkMode
              ? Colors.green.shade700
              : Colors.green.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(_isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Safest Street',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _isDarkMode
                  ? Colors.green.shade200
                  : Colors.green.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            safest!.street,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _isDarkMode
                  ? Colors.green.shade100
                  : Colors.green.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            '${safest!.totalAccidents} accident${safest!.totalAccidents != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _isDarkMode
                  ? Colors.green.shade200
                  : Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 15),
          Icon(
            Icons.check_circle,
            color: _isDarkMode
                ? Colors.green.shade300
                : Colors.green.shade600,
            size: 50,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
