#include <iostream>
using namespace std;

class Account {
	private:
		int accountNumber;
		float balance;
	
	public:
		Account(int num, float amount) {
			accountNumber = num;
			balance = amount;
		};

		int displayAccountNumber() {
			return accountNumber;
		};

		void setAccountNumber(int account_num) {
			accountNumber = account_num;
		};

		void displayBalance() {
			cout << "Balance: " << balance << " Rs" << endl;
		}

		float getBalance() {
			return balance;
		};

		void setBalance(float amount) {
			balance = amount;
		};

		void deposit(float amount) {
			balance += amount;
		};

		virtual void withdraw(float amount) {
			if (balance - amount < 0) {
				cout << "Insufficient Balance\n";
			} else {
				balance -= amount;
			}
		};
};

class SavingsAccount: public Account {
	private:
		static float savingsAccountLimit;
	
	public:
		SavingsAccount(int num, float amount): Account(num, amount) {}

		static float getLimit() {
			return savingsAccountLimit;
		}

		static void setLimit(float newLimit) {
			savingsAccountLimit = newLimit;
		}

		void withdraw(float amount) {
			if (amount > savingsAccountLimit) {
				cout << "Withdraw limit exceeded!\n";
			} else {
				Account::withdraw(amount);	
			}
		}
};


class CurrentAccount: public Account {
	private:
		static float currentAccountLimit;
	
	public:
		CurrentAccount(int num, float amount): Account(num, amount) {}
		
		static float getLimit() {
			return currentAccountLimit;
		}

		static void setLimit(float newLimit) {
			currentAccountLimit = newLimit;
		}

		void withdraw(float amount) {
			if (amount > currentAccountLimit) {
				cout << "Withdraw limit exceeded!\n";
			} else {
				Account::withdraw(amount);
			}
		}
};

float SavingsAccount::savingsAccountLimit = 50000;
float CurrentAccount::currentAccountLimit = 30000;

int main() { 
	Account* a1;
	Account* a2;

	SavingsAccount s1(1, 0);
	CurrentAccount c1(1, 0);

	a1 = &s1;
	a2 = &c1;	
	
	a1->displayBalance();
	a2->displayBalance();

	a1->deposit(60000);
	a2->deposit(40000);

	a1->displayBalance();
	a2->displayBalance();

	a1->withdraw(55000);
	a2->withdraw(29000);

	a1->displayBalance();
	a2->displayBalance();

	a1->withdraw(48000);
	a2->withdraw(20000);

	a1->displayBalance();
	a2->displayBalance();

	cout << "Savings Account Limit: " << SavingsAccount::getLimit() << " Rs\n";
	cout << "Current Account Limit: " << CurrentAccount::getLimit() << " Rs\n";
}
