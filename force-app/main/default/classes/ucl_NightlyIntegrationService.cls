public class ucl_NightlyIntegrationService {

    
    public static void performNightlyIntegration() {
        try {
           
            String herokuData = fetchDataFromHeroku();
            // Parseo de datos
            List<ucl_LegalAdvisorWrapper> legalAdvisors = parseHerokuData(herokuData);

            // update o insert de informacion
            upsertLegalAdvisorsAndClients(legalAdvisors);

        } catch (Exception ex) {
            // Error Logging
             logError(ex.getMessage(), ex.getStackTraceString(), 'Info de registros afectados');
            // Envio de correo
             sendErrorNotification(ex.getMessage());
        }
    }
	
    // Método para filtrar asesores legales habilitados
      private static List<ucl_LegalAdvisorWrapper> filterEnabledAdvisors(List<ucl_LegalAdvisorWrapper> legalAdvisors) {
        List<ucl_LegalAdvisorWrapper> enabledAdvisors = new List<ucl_LegalAdvisorWrapper>();
        for (ucl_LegalAdvisorWrapper advisor : legalAdvisors) {
            if (advisor.AccountStatus == 'Enabled') {
                enabledAdvisors.add(advisor);
            }
        }
        return enabledAdvisors;
    }
    // Método para recuperar datos desde Heroku
    private static String fetchDataFromHeroku() {
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
    private static List<ucl_LegalAdvisorWrapper> parseHerokuData(String herokuData) {
        return (List<ucl_LegalAdvisorWrapper>)JSON.deserialize(herokuData, List<ucl_LegalAdvisorWrapper>.class);
    }

    // Método para el update o insert de Asesores Legales y Clientes
    private static void upsertLegalAdvisorsAndClients(List<ucl_LegalAdvisorWrapper> legalAdvisors) {
        List<ucl_Legal_Advisor__c> legalAdvisorsToUpsert = new List<ucl_Legal_Advisor__c>();
        List<ucl_Client__c> clientsToUpsert = new List<ucl_Client__c>();

        for (ucl_LegalAdvisorWrapper advisorWrapper : legalAdvisors) {
            ucl_Legal_Advisor__c legalAdvisor = new ucl_Legal_Advisor__c(
                Account_Number__c = advisorWrapper.AccountNumber,
                Name = advisorWrapper.AccountName,
                Account_Status__c = advisorWrapper.AccountStatus,
                As_Of_Date_Date__c = Date.valueOf(advisorWrapper.AsOfDate)
            );

            // Assuming AccountNumber is an external ID
            legalAdvisorsToUpsert.add(legalAdvisor);

            for (ucl_ClientWrapper clientWrapper : advisorWrapper.Clients) {
                ucl_Client__c client = new ucl_Client__c(
                    Name = clientWrapper.FirstName,
                    Last_Name__c = clientWrapper.LastName,
                    Email__c = clientWrapper.Email,
                    Phone__c = clientWrapper.Phone,
                    Address__c = clientWrapper.Address,
                    Client_Number__c = clientWrapper.ClientNumber
                );

                // Assuming ClientNumber is an external ID
                clientsToUpsert.add(client);
            }
        }

        // Update o insert de Legal Advisors
        //upsert legalAdvisorsToUpsert Account_Number__c;

        // Update o insert de Clients
        //upsert clientsToUpsert Client_Number__c;
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
    private class ucl_LegalAdvisorWrapper {
        public String AccountNumber;
        public String AccountName;
        public String AccountStatus;
        public String AsOfDate;
        public List<ucl_ClientWrapper> Clients;
    }

    // Wrapper class for Client data
    private class ucl_ClientWrapper {
        public String FirstName;
        public String LastName;
        public String Email;
        public String Phone;
        public String Address;
        public String ClientNumber;
    }
}