/**
 * @file WritingExample.cpp
 * @author PeterC (petercalifano.gs@gmail.com)
 * @brief
 * @version 0.1
 * @date 2024-07-18
 * @detail Key concepts from documentation.
 * All defs in one proto are in namespace <package name>.
 * "Required" is forever. Cannot be removed from messages and must always be specified.
 * @note Reference: https://protobuf.dev/getting-started/cpptutorial/
 */

#include <iostream>
#include <addressbook.pb.h>
#include <fstream>
#include <string>

using namespace std;

// From tutorial: This function fills in a Person message based on user input.
void PromptForAddress(tutorial::Person *person)
{
    // Get ID number from user input and set in Person object
    cout << "Enter person ID number: ";
    int id;
    cin >> id;
    person->set_id(id);
    cin.ignore(256, '\n');

    // Do the same with name, getline is used because input is a char array
    cout << "Enter name: ";
    getline(cin, *person->mutable_name());

    // This is instead how one could do the same with strings
    cout << "Enter email address (blank for none): ";
    string email;
    getline(cin, email);
    if (!email.empty())
    {
        person->set_email(email); // Note: all the set_ methods are like set_<fieldname> getting as input the type 
    }

    // Loop to input as many phone numbers as desired
    // Note that phone type number is an enum type, whereas PhoneNumber is repeated (i.e. the message can contain as many as needed)
    while (true)
    {
        cout << "Enter a phone number (or leave blank to finish): ";
        string number;
        getline(cin, number);
        if (number.empty())
        {
            break;
        }

        tutorial::Person::PhoneNumber *phone_number = person->add_phones();
        phone_number->set_number(number);

        cout << "Is this a mobile, home, or work phone? ";
        string type;
        getline(cin, type);
        if (type == "mobile")
        {
            phone_number->set_type(tutorial::Person::PHONE_TYPE_MOBILE);
        }
        else if (type == "home")
        {
            phone_number->set_type(tutorial::Person::PHONE_TYPE_HOME);
        }
        else if (type == "work")
        {
            phone_number->set_type(tutorial::Person::PHONE_TYPE_WORK);
        }
        else
        {
            cout << "Unknown phone type.  Using default." << endl;
        }
    }
}

int main(int argc, char *argv[])
{
    std::cout << "Protobuf example message serialization" << endl;
    // Verify that the version of the library that we linked against is
    // compatible with the version of the headers we compiled against.
    GOOGLE_PROTOBUF_VERIFY_VERSION;

    if (argc != 2)
    {
        cerr << "Usage:  " << argv[0] << " ADDRESS_BOOK_FILE" << endl;
        return -1;
    }

    // Instantiate an address book object (message)
    tutorial::AddressBook address_book;

    {
        // Read the existing address book if provided as input to main
        fstream input(argv[1], ios::in | ios::binary);
        if (!input)
        {
            cout << argv[1] << ": File not found.  Creating a new file." << endl;
        }
        else if (!address_book.ParseFromIstream(&input))
        {
            cerr << "Failed to parse address book." << endl;
            return -1;
        }
    }

    // Start adding addresses if any
    PromptForAddress(address_book.add_people());

    {
        // Write the new address book back to disk.
        fstream output(argv[1], ios::out | ios::trunc | ios::binary);
        if (!address_book.SerializeToOstream(&output))
        {
            cerr << "Failed to write address book." << endl;
            return -1;
        }
    }

    // Optional: Delete all global objects allocated by libprotobuf.
    google::protobuf::ShutdownProtobufLibrary();
    // This is not strictly needed, but you should do it if there is a memory leak check or when writing a library reloaded multiple times

    cout << "TEST END" << endl;
    return 0;
}