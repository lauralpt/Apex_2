global class UclNightlyIntegrationServiceScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        UclNightlyIntegrationService job = new UclNightlyIntegrationService();
        String cronExp = '0 0 11 * * ?'; 
        System.schedule('UclNightlyIntegrationServiceJob', cronExp, job);
    }
}