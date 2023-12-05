public class UclClientWrapper {
 public String firstName;
    public String lastName;
    public String email;
    public String phone;
    public String address;
    public String clientNumber;

    // Constructor
    public UclClientWrapper(String fName, String lName, String mail, String ph, String addr, String clientNum) {
        this.firstName = fName;
        this.lastName = lName;
        this.email = mail;
        this.phone = ph;
        this.address = addr;
        this.clientNumber = clientNum;
    }
}