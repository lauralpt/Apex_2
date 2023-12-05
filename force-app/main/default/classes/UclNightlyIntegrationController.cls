public with sharing class UclNightlyIntegrationController {
    @AuraEnabled
    public static void performNightlyIntegration() {
        UclNightlyIntegrationService serviceInstance = new UclNightlyIntegrationService();
        serviceInstance.getPerformNightlyIntegration();
    }
}