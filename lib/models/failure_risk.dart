import 'dart:math';

enum RiskCategory {
  overstock,
  stockout,
  demandMismatch,
  logisticDelay,
  pricingWar,
}

class FailureRisk {
  final String id;
  final String title;
  final String subTitle;
  final int propagationScore;
  final String urgencyWindow;
  final String updatedTime;
  final RiskCategory category;
  final double exposure;
  final List<ImpactPoint> impactPoints;
  final List<MitigationAction> mitigationActions;

  FailureRisk({
    required this.id,
    required this.title,
    required this.subTitle,
    required this.propagationScore,
    required this.urgencyWindow,
    required this.updatedTime,
    required this.category,
    required this.exposure,
    required this.impactPoints,
    required this.mitigationActions,
  });

  static List<FailureRisk> get mockData => [
    generateRandom(),
    generateRandom(),
    generateRandom(),
  ];

  static FailureRisk generateRandom() {
    final titles = [
      'INVENTORY GLUT',
      'SUPPLY DISRUPTION',
      'DEMAND SPIKE',
      'LOGISTIC FAILURE',
      'SHRINKAGE ALARM',
      'MARKDOWN OVERLOAD',
      'RECALL PROTOCOL',
      'VENDOR FLUSH',
    ];
    final subtitles = [
      'PHARMACEUTICALS',
      'AUTOMOTIVE PARTS',
      'FROZEN GOODS',
      'BEAUTY PRODUCTS',
      'HOUSEHOLD TECH',
      'OUTDOOR GEAR',
      'LUXURY APPAREL',
      'FRESH PRODUCE',
    ];
    final categories = RiskCategory.values;

    final random = Random();
    final title = titles[random.nextInt(titles.length)];
    final sub = subtitles[random.nextInt(subtitles.length)];
    final cat = categories[random.nextInt(categories.length)];
    final score = 60 + random.nextInt(40);

    final windows = [
      'within 12 hours',
      'within 24 hours',
      'within 36 hours',
      'within 48 hours',
    ];
    final window = windows[random.nextInt(windows.length)];

    return FailureRisk(
      id: 'RISK-${random.nextInt(99999)}',
      title: title,
      subTitle: sub,
      propagationScore: score,
      urgencyWindow: window,
      updatedTime: 'Just Now',
      category: cat,
      exposure: 50000.0 + random.nextInt(200000),
      impactPoints: [
        ImpactPoint(
          title: 'REVENUE LOSS',
          description:
              'Projected financial erosion in ${sub.toLowerCase()} category exceeding ₹${(15000 + random.nextInt(35000))}.',
        ),
        ImpactPoint(
          title: 'INVENTORY AGE',
          description:
              'Stock rotation efficiency dropped to ${40 + random.nextInt(20)}% against the 85% benchmark.',
        ),
        ImpactPoint(
          title: 'MARKET REASON',
          description:
              'Unplanned volatility detected due to competitive shift in local distribution nodes.',
          isCritical: true,
        ),
      ],
      mitigationActions: [
        MitigationAction(
          title: 'Tiered Markdown',
          description:
              'Deploy aggressive pricing strategy to liquidate ageing stock.',
          recoveryLabel: '+28% recovery',
        ),
        MitigationAction(
          title: 'Cross-Promotion',
          description:
              'Bundle affected units with high-velocity SKU inventory.',
          recoveryLabel: '+15% margin offset',
        ),
      ],
    );
  }
}

class ImpactPoint {
  final String title;
  final String description;
  final bool isCritical;

  ImpactPoint({
    required this.title,
    required this.description,
    this.isCritical = false,
  });
}

class MitigationAction {
  final String title;
  final String description;
  final String recoveryLabel;

  MitigationAction({
    required this.title,
    required this.description,
    required this.recoveryLabel,
  });
}
