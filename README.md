# README

This repo is created using ruby 2.5.1 in order to support the Master Thesis presented by Pablo Adell to the UC3M on the topic: _Inflating Hyperloglog Cardinality Estimates: Algorithms and Applications._

## Installation

First of all, install all the necessary dependencies by executing:

```bash
bundle install
```

Then setup and create the database by executing

```bash
rake db:create
```

And create all the tables with:

```bash
rake db:migrate
```

Also two additional tables "summary_test" and "summary_conversions" should be created using mysql command line

```bash
CREATE TABLE summary_test (date date, hll VARBINARY(10240))

CREATE TABLE summary_conversions (hll VARBINARY(8197))
```

Then go to [PrestoDB webpage](https://prestodb.io/docs/current/installation.html) and follow the installation tutorial.

Create a catalog for your mysql as

```bash
connector.name=mysql
connection-url=jdbc:mysql://localhost:your_mysql_port?useSSl=false
connection-user=root
connection-password=root
```

Finally create a .env file with:

```bash
SLACK_TOKEN=xoxb-xxxxxxxxx
```

This will allow you to receive all the updates as the phases execute when the attack is running

## Usage

Start the presto server by navigating to presto\__version_/bin and executing

```bash
./launcher start
```

Once the server is started, update the values in /lib/utils/presto.db with those you chose when configuring presto

```bash
 @client = Presto::Client.new(
        server: "localhost:8080",   #Require option where your presto server is  running
        ss: {verify: false},
        catalog: "mysql",           #The catalog you want to use with presto
        schema: "test",             #Default schema to be used in the database
        user: "root",
        time_zone: "US/Pacific",
        language: "English"
      )
```

In order to run the attack start the rails console

```bash
rails c
```

And execute the controller method:

```bash
Api::AttackController.new(expectedCardinality, currentCardinality).all
```

currentCardinality is set to 0 by default but you can change it in order to modify the script.
The method _all_ will reset the database and execute all the different phases of the attack, sending a slack message after each phase regarding the API key in .env

## Redis Test

Additionally, the same attack can be performed in Redis by executing it as follows 

```bash
python redis_test.py
```

## Contributing

Pull requests are welcome as many sections of the code are boilerplate. For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)
