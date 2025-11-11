#include <iostream>
using namespace std;

int main() {
        // 1
	int x = 10;
	int* ptr1 = &x;
	cout << "Value = " << *ptr1 << " Address = " << ptr1 << endl;
	cout << endl;

	// 2
	int** ptr2 = &ptr1;
       	cout << "*ptr1 = " << *ptr1 << endl; 	
       	cout << "ptr1 = " << ptr1 << endl;
       	cout << "ptr2 = " << ptr2 << endl;
       	cout << "*ptr2 = " << *ptr2 << endl; 	
       	cout << "**ptr2 = " << **ptr2 << endl;
	cout << endl;	

	// 3
	int n;
	cout << "Enter no of integers = ";
	cin >> n;
	int* arr = new int[n];
	cout << endl;

	// 4
	int num;
	for (int i=0; i<n; i++) {
		cout << "Enter integer " << i+1 << ": ";
		cin >> *(arr+i);
	}
	cout << endl;

	// 5
	for (int i=0; i<n; i++) {
		cout << "arr[" << i << "]: " << *(arr+i) << " Address: " << arr+i << endl;
	}
	cout << endl;

	// 6
	delete[] arr;
	arr = nullptr;
}

