import ballerina/xmldata;
import ballerina/http;

//xml namespace declaration
xmlns "http://www.example.com/orders" as eg;

# The `orders` record represents the `orders` element in the XML.
#
# + 'xmlns - The `xmlns` attribute of the `orders` element 
# + 'order - The `order` elements in the `orders` element
@xmldata:Namespace {uri: "http://www.example.com/orders"}
type orders record {
    @xmldata:Attribute
    string 'xmlns?;
    Order[] 'order;
};

# The `Order` record represents the `order` element in the XML.
#
# + id - The `id` attribute of the `order` element  
# + customer - The `customer` element in the `order` element  
# + items - The `items` element in the `order` element
type Order record {
    @xmldata:Attribute
    string id;
    Customer customer;
    Items items;
};

# The `Items` record represents the `items` element in the XML.
#
# + item - The `item` elements in the `items` element
type Items record {
    Item[] item;
};

# The `Customer` record represents the `customer` element in the XML.
#
# + name - The `name` element in the `customer` element 
# + email - The `email` element in the `customer` element
type Customer record {
    string name;
    readonly string email;
};

# The `Item` record represents the `item` element in the XML.
#
# + id - The `id` attribute of the `item` element
# + name - The `name` element in the `item` element
# + quantity - The `quantity` element in the `item` element  
# + price - The `price` element in the `item` element
type Item record {
    @xmldata:Attribute
    readonly string id;
    string name;
    int quantity;
    float price;
};

# The `OrderSummary` record represents the `orderSummary` element in the XML.
#
# + orderId - The `orderId` element in the `orderSummary` element 
# + name - The `name` element in the `orderSummary` element  
# + email - The `email` element in the `orderSummary` element  
# + total - The `totalAmount` element in the `orderSummary` element
type OrderSummary record {
    string orderId;
    string name;
    string email;
    float total;
};

# The `itemType` record represents the `item` element in the XML.
#
# + id - The `id` attribute of the `item` element  
# + name - The `name` element in the `item` element  
# + price - The `price` element in the `item` element
type itemType record {
    string id;
    string name;
    float price;
};

service / on new http:Listener(8000) {

    // The `orderClient` is used to call the `orders` service.
    private http:Client orderClient;

    # The `init` function is invoked when the service is started.
    # + return - Returns an error if failed to initialize the client
    public function init() returns error? {
        self.orderClient = check new ("http://localhost:9090/");
    }

    # The `orders` resource function is used to get the orders.
    # + return - Returns the orders or an error if failed to get the orders
    resource function get orders() returns Order[]|error {
        xml orderDetails = check self.orderClient->/orders;

        // Use xmldata:fromXml() to directly convert the xml to a record
        orders orders = check xmldata:fromXml(orderDetails);
        return orders.'order;
    }

    # The `customers` resource function is used to get the customers.
    # + return - Returns the customers or an error if failed to get the customers
    resource function get customers() returns Customer[]|error {
        return self.getCustomers();
    }

    # The `order-summary` resource function is used to get the order summary.
    # + return - Returns the order summary or an error if failed to get the order summary
    resource function get order\-summary() returns xml|error {
        xml orderDetails = check self.orderClient->/orders;

        // use query expressions in conjunction with xml templates to generate orderSummary in xml
        xml orderSummary = xml `<summary>${from var 'order in orderDetails/<eg:'order>
            select xml `<orderSummary>
                            <orderId>${check 'order.id}</orderId>
                            <name>${('order/<eg:customer>/<eg:name>).data()}</name>
                            <email>${('order/<eg:customer>/<eg:email>).data()}</email>
                            <totalAmount>${('order/<eg:total>).data()}</totalAmount>
                        </orderSummary>`}</summary>`;
        return orderSummary;
    }

    # The `order-summary` resource function is used to get the order summary.
    # + return - Returns the order summary or an error if failed to get the order summary
    resource function get unique\-customers() returns xml|error {
        Customer[] customers = check self.getCustomers();

        // Table acts as a hash table and can be used to get unique customers. 
        // If there are duplicate customers with same email, newest entry replaces the older one.
        table<Customer> key(email) uniqueCustomers = table key(email) from var customer in customers
            select customer;

        // Use query expressions in conjunction with xml templates to generate uniqueCustomers in xml
        return xml `<customers>${from var customer in uniqueCustomers
            select xml `<customer>
                            <name>${customer.name}</name>
                            <email>${customer.email}</email>
                        </customer>`}
                        </customers>`;
    }

    # The `unique-items` resource function is used to get the unique items.
    # + return - Returns the unique items or an error if failed to get the unique items
    resource function get unique\-items() returns itemType[]|error {
        xml orderDetails = check self.orderClient->/orders;
        // Use query expressions to get unique items by using creating a map out of the items using the item is as the key.
        map<itemType> uniqueItems = map from var 'order in orderDetails/<eg:'order>
            from var item in 'order/<eg:items>/<eg:item>

            // When creating a map using a query expression, the select clause must have a tuple literal with two elements, 
            // First element is the key and the second element is the value
            select [
                check item.id,
                {
                    id: check item.id,
                    name: (item/<eg:name>).data(),
                    price: check float:fromString((item/<eg:price>).data())
                }
            ];
        // Use the `toArray()` langlib function to convert the map to an array.
        return uniqueItems.toArray();
    }

    # The `getCustomers` function is used to get the customers.
    # + return - Returns the customers or an error if failed to get the customers
    private function getCustomers() returns Customer[]|error {
        xml orderDetails = check self.orderClient->/orders;
        Customer[] customers = from var 'order in orderDetails/<eg:'order>
            select {
                name: ('order/<eg:customer>/<eg:name>).data(),
                email: ('order/<eg:customer>/<eg:email>).data()
            };
        return customers;
    }
}

