public class UclNightlyIntegrationService implements Schedulable {
    
    public void execute(SchedulableContext ctx) {
        getPerformNightlyIntegration();
    }
    @future(Callout=true)
    public static void getPerformNightlyIntegration() {
        UclNightlyIntegrationService serviceInstance = new UclNightlyIntegrationService();
        try {
             // Parseo de datos
            List<UclLegalAdvisorWrapper> herokuData = serviceInstance.fetchDataFromHeroku();     
            System.debug(herokuData);
            // Filtrar asesores legales habilitados
            List<UclLegalAdvisorWrapper> enabledAdvisor = serviceInstance.filterEnabledAdvisors(herokuData);
            // update o insert de informacion
            serviceInstance.upsertLegalAdvisorsAndClients(enabledAdvisor);
        } catch (Exception ex) {
            // Error Logging
            serviceInstance.logError(ex.getMessage());
            // Envio de correo
             serviceInstance.sendErrorNotification(ex.getMessage());
        }
    }
	
    // Método para filtrar asesores legales habilitados
      private List<UclLegalAdvisorWrapper> filterEnabledAdvisors(List<UclLegalAdvisorWrapper> legalAdvisors) {
        List<UclLegalAdvisorWrapper> enabledAdvisors = new List<UclLegalAdvisorWrapper>();
        for (UclLegalAdvisorWrapper advisor : legalAdvisors) {
            if (advisor.AccountStatus == 'Enabled') {
                enabledAdvisors.add(advisor);
            }
        }
        return enabledAdvisors;
    }
    
    // Método para recuperar datos desde Heroku
    public List<UclLegalAdvisorWrapper> fetchDataFromHeroku() {
        // Url para consumir el json
        String herokuUrl = 'https://altimetrik-bootcamp.herokuapp.com/LegalAccounts';
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(herokuUrl);
        request.setMethod('GET');
        HttpResponse response = new Http().send(request);
    
        // Verificar si la solicitud fue exitosa (código de estado 200)
        if (response.getStatusCode() == 200) {
            // Deserializar el JSON a una lista de objetos LegalAccount
            String jsonString =  response.getBody();
            List<UclLegalAdvisorWrapper> legalAccounts = (List<UclLegalAdvisorWrapper>)JSON.deserialize(jsonString, List<UclLegalAdvisorWrapper>.class);
            return legalAccounts;
        } else {
            throw new CalloutException('Error obteniendo la información desde Heroku: ' 
                                       + response.getStatusCode() + ' - ' 
                                       + response.getStatus());
        }
    }

   // Método para el update o insert de Asesores Legales y Clientes
    public void upsertLegalAdvisorsAndClients(List<UclLegalAdvisorWrapper> legalAdvisors) {
    List<ucl_Legal_Advisor__c> legalAdvisorsToUpsert = new List<ucl_Legal_Advisor__c>();
    List<ucl_Client__c> clientsToUpsert = new List<ucl_Client__c>();
    Set<String> existingClientNumbers = new Set<String>();
    Map<String, ucl_Legal_Advisor__c> accountNumberToLegalAdvisor = new Map<String, ucl_Legal_Advisor__c>();

    // Obtener todos los Client Numbers existentes en Salesforce
    for (ucl_Client__c existingClient : [SELECT Client_Number__c FROM ucl_Client__c]) {
        existingClientNumbers.add(existingClient.Client_Number__c);
    }

    for (UclLegalAdvisorWrapper advisorWrapper : legalAdvisors) {
        if (advisorWrapper.accountStatus == 'Enabled') {
            ucl_Legal_Advisor__c legalAdvisor = new ucl_Legal_Advisor__c();
            Date dateD = convertStringToDate(String.valueOf(advisorWrapper.asOfDate));
            legalAdvisor.Account_Number__c = advisorWrapper.accountNumber;
            legalAdvisor.Account_Name__c = advisorWrapper.accountName;
            legalAdvisor.Account_Status__c = advisorWrapper.accountStatus;
            legalAdvisor.As_Of_Date_Date__c = dateD;

            legalAdvisorsToUpsert.add(legalAdvisor);
            // Guardar la referencia por número de cuenta
            accountNumberToLegalAdvisor.put(advisorWrapper.accountNumber, legalAdvisor);
        } else {
            ucl_Legal_Advisor__c existingLegalAdvisor = [SELECT Id, Account_Status__c FROM ucl_Legal_Advisor__c WHERE Account_Number__c = :advisorWrapper.accountNumber LIMIT 1];
            if (existingLegalAdvisor != null && existingLegalAdvisor.Account_Status__c == 'Enabled') {
                existingLegalAdvisor.Account_Status__c = 'Disabled';
                legalAdvisorsToUpsert.add(existingLegalAdvisor);
            }
        }
    }
    //Se hace el upsert de legal advisors, se mejora la logica
    Database.upsert(legalAdvisorsToUpsert, ucl_Legal_Advisor__c.Fields.Account_Number__c, false);

    // Hacer un upsert de los asesores y luego asignar el ID al cliente una vez se haya insertado correctamente.
    for (UclLegalAdvisorWrapper advisorWrapper : legalAdvisors) {
        if (advisorWrapper.accountStatus == 'Enabled') {
            ucl_Legal_Advisor__c upsertedAdvisor = accountNumberToLegalAdvisor.get(advisorWrapper.accountNumber);
            for (UclClientWrapper clientWrapper : advisorWrapper.clients) {
                ucl_Client__c client = new ucl_Client__c();
                client.First_Name__c = clientWrapper.firstName;
                client.Last_Name__c = clientWrapper.lastName;
                client.Email__c = clientWrapper.email;
                client.Phone__c = clientWrapper.phone;
                client.Address__c = clientWrapper.address;
                client.Client_Number__c = clientWrapper.clientNumber;
                client.Legal_Advisor__c = upsertedAdvisor.Id;

                clientsToUpsert.add(client);
                existingClientNumbers.add(clientWrapper.clientNumber);
            }
        }
    }

    // Eliminar clientes que no están presentes en el JSON de Heroku, excepto aquellos creados por un administrador
    List<ucl_Client__c> clientsToDelete = [SELECT Id FROM ucl_Client__c WHERE Client_Number__c NOT IN :existingClientNumbers AND CreatedBy.Profile.Name != 'System Administrator'];
    delete clientsToDelete;
    // Update o insert de Legal Advisors
    upsert legalAdvisorsToUpsert Account_Number__c;
    // Update o insert de Clients
    upsert clientsToUpsert Client_Number__c;
}

    // Método para registrar errores
    private void logError(String errorMessage) {
        ucl_Error_Log__c errorLog = new ucl_Error_Log__c();
        errorLog.errorMessage__c = errorMessage;
        errorLog.Fecha__c = Datetime.now();
        try {
            insert errorLog; 
        } catch (DmlException e) {
            System.debug('Error al registrar el log de error: ' + e.getMessage());
        }
    
        // Eliminar registros de errores de más de 30 días
        Integer retentionDays = 30;
        Date retentionDate = System.today().addDays(-retentionDays);
        List<ucl_Error_Log__c> oldErrorLogs = [SELECT Id FROM ucl_Error_Log__c WHERE CreatedDate < :retentionDate];
        
        if (!oldErrorLogs.isEmpty()) {
            delete oldErrorLogs;
        }
    }
    
    // Método para enviar el email notificador del error
     public void sendErrorNotification(String errorMessage) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String adminEmail = [SELECT Email FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1].Email;
        mail.setToAddresses(new String[] { adminEmail });
        mail.setSubject('Error en la Sincronización de Datos');
        mail.setPlainTextBody('Se produjo un error: ' + errorMessage);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
        
    // Método que realiza análisis de la cadena obtenida del json para adaptarla al formato requerido
    public static Date convertStringToDate(String dateString) {
            List<String> dateArray = dateString.split('/');
            Integer m = Integer.valueOf(dateArray[0]);
            Integer d = Integer.valueOf(dateArray[1]);
            Integer y = Integer.valueOf(dateArray[2]);
            return Date.newInstance(y, m, d);
        }
    }