import 'package:flutter/foundation.dart';

import '../../../core/commercial/commercial_model.dart';
import '../../../core/network/api_client.dart';

class ClientBillingRepository {
  ClientBillingRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<dynamic>> fetchInvoices() async {
    final json = await _apiClient.getJson('/client/invoices',
        surface: ApiSurface.client);
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAgreements() async {
    final json = await _apiClient.getJson(
      '/client/agreements',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchStatements() async {
    final json = await _apiClient.getJson(
      '/client/statements',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchReminders() async {
    final json = await _apiClient.getJson(
      '/client/reminders',
      surface: ApiSurface.client,
    );
    return (json as List? ?? const []).cast<dynamic>();
  }

  Future<List<dynamic>> fetchAgreementsSafe() async {
    try {
      return await fetchAgreements();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) rethrow;
      debugPrint('[client_billing_repository] /client/agreements failed: $error');
      return const <dynamic>[];
    }
  }

  Future<Map<String, dynamic>?> fetchSubscriptionSafe() async {
    try {
      return await fetchSubscription();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) rethrow;
      debugPrint('[client_billing_repository] /billing/subscription failed: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSubscription() async {
    final json = await _apiClient.getJson(
      '/billing/subscription',
      surface: ApiSurface.client,
    );

    if (json == null) return null;
    return Map<String, dynamic>.from(json as Map);
  }

  Future<CommercialModel> fetchCommercialModel() async {
    final json = await _apiClient.getJson('/public/pricing');
    return CommercialModel.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Begin a direct checkout at one cadence.
  ///
  /// This used to translate a lane and a tier into one of six package codes.
  /// There is one product, so the only thing left to say is how often to bill —
  /// and the server refuses anything that is not a cadence rather than picking
  /// one, because picking decides on a customer's behalf which recurring
  /// commitment they have just agreed to.
  Future<Map<String, dynamic>> createSubscription({
    required String period,
  }) async {
    final json = await _apiClient.postJson(
      '/billing/subscribe',
      body: {'period': period},
      surface: ApiSurface.client,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<String> createBillingPortalSession() async {
    final json = await _apiClient.postJson(
      '/billing/portal',
      body: const {},
      surface: ApiSurface.client,
    );

    return (json as Map)['url'] as String;
  }
}
