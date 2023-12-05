@IsTest
public class UclNightlyIntegrationServiceTest {

    @IsTest
    static void testExecute() {
        // Simular SchedulableContext
        Test.startTest();
    
        // Ejecutar el método execute del programador de trabajos programados
        UclNightlyIntegrationService scheduler = new UclNightlyIntegrationService();
        scheduler.execute(null);
    
        Test.stopTest();
    
        // Verificaa que se realizó al menos una operación DML durante la ejecución
        Integer actualDmlStatements = Limits.getDmlStatements();
        Integer expectedDmlStatements = 1;
        System.assertEquals(expectedDmlStatements, actualDmlStatements, 'Se esperaba al menos una operación DML durante la ejecución.');
    
        // Verificaa que no se enviaron correos electrónicos durante la ejecución
        Integer actualEmailInvocations = Limits.getEmailInvocations();
        Integer expectedEmailInvocations = 0;
        System.assertEquals(expectedEmailInvocations, actualEmailInvocations, 'No se deberían haber enviado correos electrónicos durante la ejecución.');
    }
    
// Método de prueba para fetchDataFromHeroku()
@IsTest
static void testFetchDataFromHeroku() {
    
    // Realizar la llamada al método para obtener los datos de Heroku
    List<UclLegalAdvisorWrapper> legalAdvisors = new UclNightlyIntegrationService().fetchDataFromHeroku();
    
    // Aserciones después de la llamada al método
    System.assertNotEquals(null, legalAdvisors, 'La lista de asesores legales no debería ser nula');
    System.assertEquals(1, legalAdvisors.size(), 'Debería haber un asesor legal en la lista');

    // Verifica la estructura y valores de un asesor legal
    UclLegalAdvisorWrapper legalAdvisor = legalAdvisors[0];
    System.assertEquals('Enabled', legalAdvisor.AccountStatus, 'El estado de la cuenta debería ser "Enabled"');
    System.assertNotEquals(null, legalAdvisor.AccountNumber, 'El número de cuenta no debería ser nulo');
    System.assertNotEquals(null, legalAdvisor.AccountName, 'El nombre de la cuenta no debería ser nulo');
    System.assertNotEquals(null, legalAdvisor.AsOfDate, 'La fecha debería estar presente');
    
    // Verifica la estructura y valores de un cliente asociado al asesor legal
    UclClientWrapper client = legalAdvisor.clients[0];
    System.assertNotEquals(null, client.FirstName, 'El nombre del cliente no debería ser nulo');
    System.assertNotEquals(null, client.LastName, 'El apellido del cliente no debería ser nulo');
    System.assertNotEquals(null, client.Email, 'El correo electrónico del cliente no debería ser nulo');
  
}

    // Método de prueba para upsertLegalAdvisorsAndClients()
    @IsTest
    static void testUpsertLegalAdvisorsAndClients() {
    // Crear datos de prueba
    List<UclLegalAdvisorWrapper> legalAdvisors = new List<UclLegalAdvisorWrapper>();
    UclLegalAdvisorWrapper legalAdvisor = new UclLegalAdvisorWrapper('123', 'Test Account', 'Enabled', Date.today());
    legalAdvisor.clients = new List<UclClientWrapper>{
    new UclClientWrapper(
        'John', // firstName
        'Doe', // lastName
        'john.doe@example.com', // email
        '1234567890', // phone
        '123 Main St', // address
        'C123' // clientNumber
    )
    };
        legalAdvisors.add(legalAdvisor);



    Test.startTest();
    UclNightlyIntegrationService serviceInstance = new UclNightlyIntegrationService();
    serviceInstance.upsertLegalAdvisorsAndClients(legalAdvisors);
    Test.stopTest();

    // Verificar que se hayan insertado correctamente los asesores legales
    List<ucl_Legal_Advisor__c> insertedLegalAdvisors = [SELECT Id, Account_Number__c, Account_Status__c FROM ucl_Legal_Advisor__c WHERE Account_Number__c = '123'];
    System.assertEquals(1, insertedLegalAdvisors.size(), 'Debería haberse insertado un asesor legal');
    System.assertEquals('Enabled', insertedLegalAdvisors[0].Account_Status__c, 'El estado del asesor legal debería ser "Enabled"');
    System.assertEquals('Test Account', insertedLegalAdvisors[0].Account_Name__c, 'El nombre de la cuenta debería ser "Test Account"');

    // Verificar que se hayan insertado correctamente los clientes asociados
    List<ucl_Client__c> insertedClients = [SELECT Id, Client_Number__c, First_Name__c FROM ucl_Client__c WHERE Client_Number__c = 'C123'];
    System.assertEquals(1, insertedClients.size(), 'Debería haberse insertado un cliente');
    System.assertEquals('C123', insertedClients[0].Client_Number__c, 'El número de cliente debería ser "C123"');
    System.assertEquals('John', insertedClients[0].First_Name__c, 'El nombre del cliente debería ser "John"');

    // Asegurar que la lógica de actualización se maneje correctamente (por ejemplo, cambiar el estado a "Disabled")
    serviceInstance.upsertLegalAdvisorsAndClients(legalAdvisors);
    List<ucl_Legal_Advisor__c> updatedLegalAdvisors = [SELECT Id, Account_Status__c FROM ucl_Legal_Advisor__c WHERE Account_Number__c = '123'];
    System.assertEquals('Disabled', updatedLegalAdvisors[0].Account_Status__c, 'El estado del asesor legal debería cambiar a "Disabled" en la actualización');

    // Asegurar manejo correcto de clientes existentes
    legalAdvisors[0].clients[0].clientNumber = 'ExistingClientNumber';
    serviceInstance.upsertLegalAdvisorsAndClients(legalAdvisors);
    List<ucl_Client__c> existingClients = [SELECT Id FROM ucl_Client__c WHERE Client_Number__c = 'ExistingClientNumber'];
    System.assertEquals(1, existingClients.size(), 'Debería existir un cliente existente con el número "ExistingClientNumber"');

    // Asegurar manejo correcto de clientes que no están presentes en el JSON de Heroku
    serviceInstance.upsertLegalAdvisorsAndClients(new List<UclLegalAdvisorWrapper>());
    List<ucl_Client__c> deletedClients = [SELECT Id FROM ucl_Client__c WHERE Client_Number__c = 'C123'];
    System.assertEquals(0, deletedClients.size(), 'El cliente debería eliminarse si no está presente en el JSON de Heroku');

    // Asegurar manejo correcto de errores durante la actualización
    Test.startTest();
    // Simular un error al intentar actualizar asesores legales y clientes
    serviceInstance.upsertLegalAdvisorsAndClients(legalAdvisors);
    Test.stopTest();
    // Verificar que se haya registrado un error
    List<ucl_Error_Log__c> errorLogs = [SELECT Id FROM ucl_Error_Log__c];
    System.assertEquals(1, errorLogs.size(), 'Debería haberse registrado un error durante la actualización');
}

@isTest
static void testSendErrorNotification() {
    
    Test.startTest();
    UclNightlyIntegrationService errorHandlingInstance = new  UclNightlyIntegrationService();

    // Usa un correo electrónico ficticio para evitar enviar correos electrónicos reales
    String testAdminEmail = 'testadmin@example.com';
    // Crea un usuario de prueba con el perfil 'System Administrator'
    Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    User testAdminUser = new User(
        FirstName = 'Test',
        LastName = 'Admin',
        Email = testAdminEmail,
        Username = 'testadmin@example.com',
        ProfileId = adminProfile.Id,
        Alias = 'tadmin',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        TimeZoneSidKey = 'America/Los_Angeles'
    );
    insert testAdminUser;

    // Verifica que el correo del administrador es el esperado
    System.assertEquals(testAdminEmail, [SELECT Email FROM User WHERE Id = :testAdminUser.Id].Email, 'El correo del administrador no coincide.');
    errorHandlingInstance.sendErrorNotification('Test Error Message');

    // Verifica que se haya enviado el correo de notificación
    List<EmailMessage> sentEmails = [SELECT Id, Subject, HtmlBody FROM EmailMessage];
    System.assertNotEquals(0, sentEmails.size(), 'El correo de notificación no se envió correctamente.');

    EmailMessage sentEmail = sentEmails[0];
    System.assertEquals('Error en la Sincronización de Datos', sentEmail.Subject, 'El asunto del correo no coincide.');
    System.assert(sentEmail.HtmlBody.contains('Test Error Message'), 'El mensaje de error no está presente en el cuerpo del correo.');

    // Limpieza: Elimina los correos electrónicos de prueba
    delete sentEmails;

    Test.stopTest();
  }



}

