import 'dart:convert';

String _text(Object? value) => value?.toString() ?? '';

int _number(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

DateTime? _nullableDate(Object? value) {
  if (value == null || value.toString().isEmpty) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return <String, String>{};
  return value.map(
    (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
  );
}

class CrmCustomer {
  const CrmCustomer({
    required this.id,
    required this.name,
    required this.company,
    required this.mobile,
    required this.phone,
    required this.province,
    required this.city,
    required this.activityType,
    required this.status,
    required this.priority,
    required this.notes,
    required this.tags,
    required this.updatedAt,
    this.details = const {},
    this.deleted = false,
  });

  final String id;
  final String name;
  final String company;
  final String mobile;
  final String phone;
  final String province;
  final String city;
  final String activityType;
  final String status;
  final String priority;
  final String notes;
  final List<String> tags;
  final DateTime updatedAt;
  final Map<String, String> details;
  final bool deleted;

  String get customerCode => details['customer_code'] ?? '';
  bool get isVip => details['is_vip'] == 'true';
  String get displayName => company.isEmpty ? name : company;

  CrmCustomer copyWith({
    String? name,
    String? company,
    String? mobile,
    String? phone,
    String? province,
    String? city,
    String? activityType,
    String? status,
    String? priority,
    String? notes,
    List<String>? tags,
    DateTime? updatedAt,
    Map<String, String>? details,
    bool? deleted,
  }) {
    return CrmCustomer(
      id: id,
      name: name ?? this.name,
      company: company ?? this.company,
      mobile: mobile ?? this.mobile,
      phone: phone ?? this.phone,
      province: province ?? this.province,
      city: city ?? this.city,
      activityType: activityType ?? this.activityType,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      updatedAt: updatedAt ?? this.updatedAt,
      details: details ?? this.details,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'mobile': mobile,
      'phone': phone,
      'province': province,
      'city': city,
      'activity_type': activityType,
      'status': status,
      'priority': priority,
      'notes': notes,
      'tags': tags,
      'details': details,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'mobile': mobile,
      'phone': phone,
      'province': province,
      'city': city,
      'activity_type': activityType,
      'status': status,
      'priority': priority,
      'notes': notes,
      'tags_json': jsonEncode(tags),
      'details_json': jsonEncode(details),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': deleted ? 1 : 0,
    };
  }

  factory CrmCustomer.fromJson(Map<String, dynamic> value) {
    final rawTags = value['tags'];
    final tags = rawTags is List
        ? rawTags.map((item) => item.toString()).toList()
        : <String>[];
    return CrmCustomer(
      id: _text(value['id']),
      name: _text(value['name']),
      company: _text(value['company']),
      mobile: _text(value['mobile']),
      phone: _text(value['phone']),
      province: _text(value['province']),
      city: _text(value['city']),
      activityType: _text(value['activity_type']),
      status: _text(value['status']),
      priority: _text(value['priority']),
      notes: _text(value['notes']),
      tags: tags,
      updatedAt: _date(value['updated_at']),
      details: _stringMap(value['details']),
      deleted: value['deleted'] == true || value['is_deleted'] == 1,
    );
  }

  factory CrmCustomer.fromDatabase(Map<String, Object?> value) {
    final rawTags = _text(value['tags_json']);
    final decodedTags = rawTags.isEmpty
        ? const <dynamic>[]
        : jsonDecode(rawTags);
    final tags = decodedTags is List
        ? decodedTags.map<String>((item) => item.toString()).toList()
        : <String>[];
    final rawDetails = _text(value['details_json']);
    final decodedDetails = rawDetails.isEmpty ? null : jsonDecode(rawDetails);
    return CrmCustomer(
      id: _text(value['id']),
      name: _text(value['name']),
      company: _text(value['company']),
      mobile: _text(value['mobile']),
      phone: _text(value['phone']),
      province: _text(value['province']),
      city: _text(value['city']),
      activityType: _text(value['activity_type']),
      status: _text(value['status']),
      priority: _text(value['priority']),
      notes: _text(value['notes']),
      tags: tags,
      updatedAt: _date(value['updated_at']),
      details: _stringMap(decodedDetails),
      deleted: _number(value['is_deleted']) == 1,
    );
  }
}

class CrmCall {
  const CrmCall({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.subject,
    required this.type,
    required this.direction,
    required this.status,
    required this.notes,
    required this.callAt,
    required this.durationMinutes,
    required this.amount,
    required this.updatedAt,
    this.nextFollowUp,
    this.tradeType = '',
    this.productName = '',
    this.quantity = 0,
    this.unitPrice = 0,
    this.discountAmount = 0,
    this.taxPercent = 0,
    this.deleted = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String subject;
  final String type;
  final String direction;
  final String status;
  final String notes;
  final DateTime callAt;
  final int durationMinutes;
  final int amount;
  final DateTime? nextFollowUp;
  final DateTime updatedAt;
  final String tradeType;
  final String productName;
  final int quantity;
  final int unitPrice;
  final int discountAmount;
  final int taxPercent;
  final bool deleted;

  int get subtotal =>
      quantity > 0 && unitPrice > 0 ? quantity * unitPrice : amount;
  int get netAmount => (subtotal - discountAmount).clamp(0, 1 << 62);
  int get taxAmount => (netAmount * taxPercent / 100).round();
  int get totalAmount => netAmount + taxAmount;
  bool get hasTradeOutcome =>
      status == 'موفق' && {'خرید', 'فروش'}.contains(tradeType);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'subject': subject,
      'type': type,
      'direction': direction,
      'status': status,
      'notes': notes,
      'call_at': callAt.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'amount': amount,
      'trade_type': tradeType,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_amount': discountAmount,
      'tax_percent': taxPercent,
      'next_follow_up': nextFollowUp?.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'subject': subject,
      'type': type,
      'direction': direction,
      'status': status,
      'notes': notes,
      'call_at': callAt.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'amount': amount,
      'trade_type': tradeType,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_amount': discountAmount,
      'tax_percent': taxPercent,
      'next_follow_up': nextFollowUp?.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': deleted ? 1 : 0,
    };
  }

  factory CrmCall.fromJson(Map<String, dynamic> value) {
    return CrmCall(
      id: _text(value['id']),
      customerId: _text(value['customer_id']),
      customerName: _text(value['customer_name']),
      subject: _text(value['subject']),
      type: _text(value['type']),
      direction: _text(value['direction']),
      status: _text(value['status']),
      notes: _text(value['notes']),
      callAt: _date(value['call_at']),
      durationMinutes: _number(value['duration_minutes']),
      amount: _number(value['amount']),
      tradeType: _text(value['trade_type']),
      productName: _text(value['product_name']),
      quantity: _number(value['quantity']),
      unitPrice: _number(value['unit_price']),
      discountAmount: _number(value['discount_amount']),
      taxPercent: _number(value['tax_percent']),
      nextFollowUp: _nullableDate(value['next_follow_up']),
      updatedAt: _date(value['updated_at']),
      deleted: value['deleted'] == true || value['is_deleted'] == 1,
    );
  }

  factory CrmCall.fromDatabase(Map<String, Object?> value) {
    return CrmCall(
      id: _text(value['id']),
      customerId: _text(value['customer_id']),
      customerName: _text(value['customer_name']),
      subject: _text(value['subject']),
      type: _text(value['type']),
      direction: _text(value['direction']),
      status: _text(value['status']),
      notes: _text(value['notes']),
      callAt: _date(value['call_at']),
      durationMinutes: _number(value['duration_minutes']),
      amount: _number(value['amount']),
      tradeType: _text(value['trade_type']),
      productName: _text(value['product_name']),
      quantity: _number(value['quantity']),
      unitPrice: _number(value['unit_price']),
      discountAmount: _number(value['discount_amount']),
      taxPercent: _number(value['tax_percent']),
      nextFollowUp: _nullableDate(value['next_follow_up']),
      updatedAt: _date(value['updated_at']),
      deleted: _number(value['is_deleted']) == 1,
    );
  }
}

class CrmProduct {
  const CrmProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.unit,
    required this.unitPrice,
    required this.stock,
    required this.minStock,
    required this.description,
    required this.updatedAt,
    this.isActive = true,
    this.deleted = false,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final String unit;
  final int unitPrice;
  final int stock;
  final int minStock;
  final String description;
  final DateTime updatedAt;
  final bool isActive;
  final bool deleted;

  bool get needsRestock => stock <= minStock;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'category': category,
      'unit': unit,
      'unit_price': unitPrice,
      'stock': stock,
      'min_stock': minStock,
      'description': description,
      'is_active': isActive,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }

  factory CrmProduct.fromJson(Map<String, dynamic> value) {
    return CrmProduct(
      id: _text(value['id']),
      name: _text(value['name']),
      sku: _text(value['sku']),
      category: _text(value['category']),
      unit: _text(value['unit']),
      unitPrice: _number(value['unit_price']),
      stock: _number(value['stock']),
      minStock: _number(value['min_stock']),
      description: _text(value['description']),
      isActive: value['is_active'] != false && value['is_active'] != 0,
      updatedAt: _date(value['updated_at']),
      deleted: value['deleted'] == true || value['is_deleted'] == 1,
    );
  }
}

class CrmOpportunity {
  const CrmOpportunity({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.title,
    required this.stage,
    required this.amount,
    required this.probability,
    required this.notes,
    required this.ownerName,
    required this.updatedAt,
    this.expectedClose,
    this.tradeType = 'فروش',
    this.productName = '',
    this.province = '',
    this.city = '',
    this.deleted = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String title;
  final String stage;
  final int amount;
  final int probability;
  final String notes;
  final String ownerName;
  final String tradeType;
  final String productName;
  final String province;
  final String city;
  final DateTime? expectedClose;
  final DateTime updatedAt;
  final bool deleted;

  int get weightedAmount => (amount * probability / 100).round();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'title': title,
      'stage': stage,
      'amount': amount,
      'probability': probability,
      'notes': notes,
      'owner_name': ownerName,
      'trade_type': tradeType,
      'product_name': productName,
      'province': province,
      'city': city,
      'expected_close': expectedClose?.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }

  factory CrmOpportunity.fromJson(Map<String, dynamic> value) {
    return CrmOpportunity(
      id: _text(value['id']),
      customerId: _text(value['customer_id']),
      customerName: _text(value['customer_name']),
      title: _text(value['title']),
      stage: _text(value['stage']),
      amount: _number(value['amount'] ?? value['expected_amount']),
      probability: _number(value['probability']),
      notes: _text(value['notes']),
      ownerName: _text(value['owner_name']),
      tradeType: _text(value['trade_type']).isEmpty
          ? 'فروش'
          : _text(value['trade_type']),
      productName: _text(value['product_name']),
      province: _text(value['province']),
      city: _text(value['city']),
      expectedClose: _nullableDate(value['expected_close']),
      updatedAt: _date(value['updated_at']),
      deleted: value['deleted'] == true || value['is_deleted'] == 1,
    );
  }
}

class CrmTask {
  const CrmTask({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.title,
    required this.taskType,
    required this.priority,
    required this.status,
    required this.notes,
    required this.updatedAt,
    this.dueAt,
    this.ownerName = '',
    this.deleted = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String title;
  final String taskType;
  final String priority;
  final String status;
  final String notes;
  final DateTime? dueAt;
  final String ownerName;
  final DateTime updatedAt;
  final bool deleted;

  bool get isDone => status == 'انجام شد';
  bool get isOverdue =>
      !isDone && dueAt != null && dueAt!.isBefore(DateTime.now());

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'title': title,
      'task_type': taskType,
      'priority': priority,
      'status': status,
      'notes': notes,
      'due_at': dueAt?.toUtc().toIso8601String(),
      'owner_name': ownerName,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }

  factory CrmTask.fromJson(Map<String, dynamic> value) {
    return CrmTask(
      id: _text(value['id']),
      customerId: _text(value['customer_id']),
      customerName: _text(value['customer_name']),
      title: _text(value['title']),
      taskType: _text(value['task_type']),
      priority: _text(value['priority']),
      status: _text(value['status']),
      notes: _text(value['notes']),
      dueAt: _nullableDate(value['due_at']),
      ownerName: _text(value['owner_name']),
      updatedAt: _date(value['updated_at']),
      deleted: value['deleted'] == true || value['is_deleted'] == 1,
    );
  }
}

class CrmDocumentLine {
  const CrmDocumentLine({
    required this.productCode,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.discountPercent,
    required this.taxPercent,
  });

  final String productCode;
  final String description;
  final int quantity;
  final String unit;
  final int unitPrice;
  final int discountPercent;
  final int taxPercent;

  int get grossAmount => quantity * unitPrice;
  int get discountAmount => (grossAmount * discountPercent / 100).round();
  int get netAmount => grossAmount - discountAmount;
  int get taxAmount => (netAmount * taxPercent / 100).round();
  int get totalAmount => netAmount + taxAmount;

  Map<String, dynamic> toJson() => {
    'product_code': productCode,
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'unit_price': unitPrice,
    'discount_percent': discountPercent,
    'tax_percent': taxPercent,
  };

  factory CrmDocumentLine.fromJson(Map<String, dynamic> value) {
    return CrmDocumentLine(
      productCode: _text(value['product_code']),
      description: _text(value['description']),
      quantity: _number(value['quantity']),
      unit: _text(value['unit']).isEmpty ? 'عدد' : _text(value['unit']),
      unitPrice: _number(value['unit_price']),
      discountPercent: _number(value['discount_percent']),
      taxPercent: _number(value['tax_percent']),
    );
  }
}

List<CrmDocumentLine> _documentLines(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => CrmDocumentLine.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

class CrmQuote {
  const CrmQuote({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.quoteNumber,
    required this.status,
    required this.totalAmount,
    required this.notes,
    required this.updatedAt,
    this.validUntil,
    this.direction = 'فروش',
    this.lineItems = const [],
    this.deleted = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String quoteNumber;
  final String status;
  final int totalAmount;
  final String notes;
  final DateTime? validUntil;
  final String direction;
  final List<CrmDocumentLine> lineItems;
  final DateTime updatedAt;
  final bool deleted;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'quote_number': quoteNumber,
      'status': status,
      'total_amount': totalAmount,
      'notes': notes,
      'valid_until': validUntil?.toUtc().toIso8601String(),
      'direction': direction,
      'line_items': lineItems.map((item) => item.toJson()).toList(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }

  factory CrmQuote.fromJson(Map<String, dynamic> value) {
    return CrmQuote(
      id: _text(value['id']),
      customerId: _text(value['customer_id']),
      customerName: _text(value['customer_name']),
      quoteNumber: _text(value['quote_number']),
      status: _text(value['status']),
      totalAmount: _number(value['total_amount']),
      notes: _text(value['notes']),
      validUntil: _nullableDate(value['valid_until']),
      direction: _text(value['direction']).isEmpty
          ? 'فروش'
          : _text(value['direction']),
      lineItems: _documentLines(value['line_items']),
      updatedAt: _date(value['updated_at']),
      deleted: value['deleted'] == true || value['is_deleted'] == 1,
    );
  }
}

class CrmOrder {
  const CrmOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.orderNumber,
    required this.direction,
    required this.status,
    required this.totalAmount,
    required this.notes,
    required this.orderAt,
    required this.updatedAt,
    this.lineItems = const [],
    this.sourceType = '',
    this.sourceId = '',
    this.deleted = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String orderNumber;
  final String direction;
  final String status;
  final int totalAmount;
  final String notes;
  final DateTime orderAt;
  final DateTime updatedAt;
  final List<CrmDocumentLine> lineItems;
  final String sourceType;
  final String sourceId;
  final bool deleted;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'order_number': orderNumber,
      'direction': direction,
      'status': status,
      'total_amount': totalAmount,
      'notes': notes,
      'order_at': orderAt.toUtc().toIso8601String(),
      'line_items': lineItems.map((item) => item.toJson()).toList(),
      'source_type': sourceType,
      'source_id': sourceId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }

  factory CrmOrder.fromJson(Map<String, dynamic> value) {
    return CrmOrder(
      id: _text(value['id']),
      customerId: _text(value['customer_id']),
      customerName: _text(value['customer_name']),
      orderNumber: _text(value['order_number']),
      direction: _text(value['direction']),
      status: _text(value['status']),
      totalAmount: _number(value['total_amount']),
      notes: _text(value['notes']),
      orderAt: _date(value['order_at']),
      lineItems: _documentLines(value['line_items']),
      sourceType: _text(value['source_type']),
      sourceId: _text(value['source_id']),
      updatedAt: _date(value['updated_at']),
      deleted: value['deleted'] == true || value['is_deleted'] == 1,
    );
  }
}

class SyncChange {
  const SyncChange({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.updatedAt,
    this.queueId,
  });

  final int? queueId;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'client_change_id': queueId,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': payload,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory SyncChange.fromJson(Map<String, dynamic> value) {
    final payload = value['payload'];
    return SyncChange(
      entityType: _text(value['entity_type']),
      entityId: _text(value['entity_id']),
      operation: _text(value['operation']),
      payload: payload is Map<String, dynamic>
          ? payload
          : Map<String, dynamic>.from(payload as Map? ?? const {}),
      updatedAt: _date(value['updated_at']),
      queueId: value['client_change_id'] is int
          ? value['client_change_id'] as int
          : int.tryParse(_text(value['client_change_id'])),
    );
  }
}

class SyncResponse {
  const SyncResponse({
    required this.cursor,
    required this.remoteChanges,
    required this.acceptedOutboxIds,
  });

  final int cursor;
  final List<SyncChange> remoteChanges;
  final List<int> acceptedOutboxIds;

  factory SyncResponse.fromJson(Map<String, dynamic> value) {
    final rawChanges = value['changes'] as List? ?? const [];
    final rawIds = value['accepted_outbox_ids'] as List? ?? const [];
    return SyncResponse(
      cursor: _number(value['cursor']),
      remoteChanges: rawChanges
          .map((item) => SyncChange.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      acceptedOutboxIds: rawIds.map(_number).where((item) => item > 0).toList(),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userName,
    required this.organizationId,
    required this.organizationName,
  });

  final String accessToken;
  final String userName;
  final String organizationId;
  final String organizationName;

  factory AuthSession.fromJson(Map<String, dynamic> value) {
    return AuthSession(
      accessToken: _text(value['access_token']),
      userName: _text(value['user_name']),
      organizationId: _text(value['organization_id']),
      organizationName: _text(value['organization_name']),
    );
  }
}

class SessionIdentity {
  const SessionIdentity({
    required this.userName,
    required this.organizationId,
    required this.organizationName,
  });

  final String userName;
  final String organizationId;
  final String organizationName;

  factory SessionIdentity.fromJson(Map<String, dynamic> value) {
    return SessionIdentity(
      userName: _text(value['user_name']),
      organizationId: _text(value['organization_id']),
      organizationName: _text(value['organization_name']),
    );
  }
}
