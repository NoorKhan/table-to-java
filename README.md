# table-to-java
Given a mysql database connection and a table name, it will output a java class for you based on the column types.

# Usage:
Create a `connection.config` file like so:

```
(
    hostname "localhost"
    username "username"
    password "password"
    database "database"
)
```

Next, load `table-to-java.lisp` and run `(generate-class-from-database-table "my_table")`.

Example output:

```
public class Role {

    private int roleId;
    private String roleName;
    private Boolean isActive;
    private String description;
    private boolean editable;

    public Role(int roleId, String roleName, Boolean isActive, String description, boolean editable) {
        this.roleId = roleId;
        this.roleName = roleName;
        this.isActive = isActive;
        this.description = description;
        this.editable = editable;
    }

    public int getRoleId() {
        return this.roleId;
    }

    public String getRoleName() {
        return this.roleName;
    }

    public Boolean getIsActive() {
        return this.isActive;
    }

    public String getDescription() {
        return this.description;
    }

    public boolean getEditable() {
        return this.editable;
    }
}
```
