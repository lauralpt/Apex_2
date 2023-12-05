public class UclLegalAdvisorWrapper {
public String accountNumber;
    public String accountName;
    public String accountStatus;
    public Date asOfDate;
    public List<UclClientWrapper> clients;

    // Constructor
    public UclLegalAdvisorWrapper(String accNumber, String accName, String accStatus, Date fecha) {
        this.accountNumber = accNumber;
        this.accountName = accName;
        this.accountStatus = accStatus;
        this.asOfDate = fecha;
        this.clients = new List<UclClientWrapper>();
    }
}