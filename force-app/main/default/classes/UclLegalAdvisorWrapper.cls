public class UclLegalAdvisorWrapper {
    public String accountNumber;
    public String accountName;
    public String accountStatus;
    public String asOfDate;
    public List<UclClientWrapper> clients;

    // Constructor
    public UclLegalAdvisorWrapper(String accNumber, String accName, String accStatus, String fecha) {
        this.accountNumber = accNumber;
        this.accountName = accName;
        this.accountStatus = accStatus;
        this.asOfDate = fecha;
        this.clients = new List<UclClientWrapper>();
    }
}