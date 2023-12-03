public class ucl_NightlyIntegrationService {

    
    public static void PerformNightlyIntegration() {
        try {
            String herokuData = fetchDataFromHeroku();
            // Parseo de datos
            List<UclLegalAdvisorWrapper> legalAdvisors = parseHerokuData(herokuData);
            // Filtrar asesores legales habilitados
            List<UclLegalAdvisorWrapper> enabledAdvisor = filterEnabledAdvisors(legalAdvisors);
            // update o insert de informacion
            UpsertLegalAdvisorsAndClients(enabledAdvisor);

        } catch (Exception ex) {
            // Error Logging
             logError(ex.getMessage(), ex.getStackTraceString(), 'Info de registros afectados');
            // Envio de correo
             sendErrorNotification(ex.getMessage());
        }
    }
	
    // Método para filtrar asesores legales habilitados
      private static List<UclLegalAdvisorWrapper> filterEnabledAdvisors(List<UclLegalAdvisorWrapper> legalAdvisors) {
        List<UclLegalAdvisorWrapper> enabledAdvisors = new List<UclLegalAdvisorWrapper>();
        for (UclLegalAdvisorWrapper advisor : legalAdvisors) {
            if (advisor.AccountStatus == 'Enabled') {
                enabledAdvisors.add(advisor);
            }
        }
        return enabledAdvisors;
    }
    
    // Método para recuperar datos desde Heroku
    private static String FetchDataFromHeroku() {
        // Url para consumir el json
        String herokuUrl = 'https://altimetrik-bootcamp.herokuapp.com/LegalAccounts';
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(herokuUrl);
        request.setMethod('GET');
        HttpResponse response = new Http().send(request);

        //Verifico si la solicitud fue exitosa (código de estado 200)
        if (response.getStatusCode() == 200) {
            return response.getBody();
        } else {
            throw new CalloutException('Error obteniendo la informacion desde Heroku: ' 
                                       + response.getStatusCode() + ' - ' 
                                       + response.getStatus());
        }
    }

    // Método para parsear datos JSON a la clase 
    private static List<UclLegalAdvisorWrapper> parseHerokuData(String herokuData) {
        return (List<UclLegalAdvisorWrapper>)JSON.deserialize(herokuData, List<UclLegalAdvisorWrapper>.class);
    }

    // Método para el update o insert de Asesores Legales y Clientes
    private static void UpsertLegalAdvisorsAndClients(List<UclLegalAdvisorWrapper> legalAdvisors) {
        List<ucl_Legal_Advisor__c> legalAdvisorsToUpsert = new List<ucl_Legal_Advisor__c>();
        List<ucl_Client__c> clientsToUpsert = new List<ucl_Client__c>();

        for (UclLegalAdvisorWrapper advisorWrapper : legalAdvisors) {
            ucl_Legal_Advisor__c legalAdvisor = new ucl_Legal_Advisor__c(
                Account_Number__c = advisorWrapper.accountNumber,
                Name = advisorWrapper.accountName,
                Account_Status__c = advisorWrapper.accountStatus,
                As_Of_Date_Date__c = Date.valueOf(advisorWrapper.asOfDate)
            );

            // Se asume AccountNumber is an external ID
            legalAdvisorsToUpsert.add(legalAdvisor);

            for (UclClientWrapper clientWrapper : advisorWrapper.clients) {
                ucl_Client__c client = new ucl_Client__c(
                    Name = clientWrapper.firstName,
                    Last_Name__c = clientWrapper.lastName,
                    Email__c = clientWrapper.email,
                    Phone__c = clientWrapper.phone,
                    Address__c = clientWrapper.address,
                    Client_Number__c = clientWrapper.clientNumber
                );

                // Assuming ClientNumber is an external ID
                clientsToUpsert.add(client);
            }
        }

        // Update o insert de Legal Advisors
        upsert legalAdvisorsToUpsert Account_Number__c;
        // Update o insert de Clients
        upsert clientsToUpsert Client_Number__c;
    }

    // Método para registrar errores
    private static void logError(String errorMessage, String stackTrace, String affectedRecords) {
        ucl_Error_Log__c errorLog = new ucl_Error_Log__c();
        errorLog.ErrorMessage__c = errorMessage;
        errorLog.Name = stackTrace;
        errorLog.affectedRecords__c = affectedRecords;
        insert errorLog;
    }

    // Metodo para enviar el email notificador del error
     private static void sendErrorNotification(String errorMessage) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {'lauralpt@gmail.com'};
        mail.setToAddresses(toAddresses);
        mail.setSubject('Error en la Sincronización de Datos');
        mail.setPlainTextBody('Se produjo un error: ' + errorMessage);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }


    // Wrapper class for Legal Advisor data
    private class UclLegalAdvisorWrapper {
        public String accountNumber;
        public String accountName;
        public String accountStatus;
        public String asOfDate;
        public List<UclClientWrapper> clients;
    }

    // Wrapper class for Client data
    private class UclClientWrapper {
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
        public String address;
        public String clientNumber;
    }
}