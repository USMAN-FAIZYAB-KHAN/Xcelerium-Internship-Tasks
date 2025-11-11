#include <iostream>
#include <string>
using namespace std;

struct Person {
	string name;
	int age;
	char grade;
};

int main() {
	Person p1;
	p1.name = "Usman Faizyab Khan";
	p1.age = 21;
	p1.grade = 'A';

	Person p2 = {"Umer Faizyab Khan", 23, 'A'};

	cout << "Name: " << p1.name << endl;
	cout << "Age: " << p1.age << endl;
	cout << "Grade: " << p1.grade << endl << endl;

	cout << "Name: " << p2.name << endl;
	cout << "Age: " << p2.age << endl;
	cout << "Grade: " << p2.grade << endl;
}
