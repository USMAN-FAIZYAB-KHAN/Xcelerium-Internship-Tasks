#include <iostream>
using namespace std;

int main() {
        int* arr = new int[5];
        for (int i=0; i<5; i++) {
		arr[i] = i*10;
	}
	
        for (int i=0; i<5; i++) {
		cout << arr[i] << endl;
	}

	cout << "arr (before) = " << arr << endl;
	delete[] arr;
	arr = nullptr;
	cout << "arr (after) = " << arr << endl;
	
}

