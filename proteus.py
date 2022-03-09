from decimal import *
getcontext().prec = 30

truncateTo = Decimal('.00000001')

class Proteus:

    def __init__(self, params):
        self.a = Decimal(params[0])
        self.b = Decimal(params[1])
        self.c = Decimal(params[2])
        self.d = Decimal(params[3])
        self.e = Decimal(params[4])
        self.f = Decimal(params[5])

        self.identity_util = self.calculate_identity_util()
    
    def calculate_identity_util(self):
        #at x = y
        identity_util = 0
        
        if self.a + self.b + self.c != 0:
            identity_util = self.solve_quadratic(self.a + self.b + self.c, self.d + self.e, self.f)
        else:
            identity_util = -self.f/(self.d + self.e)

        assert identity_util > 0, 'Curve does not intersect y = x in Q1'
        return identity_util

    def solve_quadratic(self, a, b, c):

        desc = (b ** 2) - (4 * a * c)

        root1 = ( -b + desc.sqrt() ) / ( 2 * a )
        root2 = ( -b - desc.sqrt() ) / ( 2 * a )

        if root1 > 0 and root1 < root2: 
            return root1
        elif root2 > 0 and root2 < root1: 
            return root2
        elif root1 > 0 and root2 < 0: 
            return root1
        elif root2 > 0 and root1 < 0: 
            return root2
        else: 
            raise Exception('cannnot solve quadratic. input values are a = {a}, b = {b}, c = {c}.'.format(a=a,b=b,c=c))
    

    def get_utility(self, x, y):

        m = Decimal(y / x)

        x_prime = 0

        if self.a + self.b + self.c != 0:
            x_prime = self.solve_quadratic( self.a + ( self.b * m ) + ( self.c * m**2 ), self.d + ( self.e * m ), self.f )
        elif self.b != 0:
            x_prime = self.solve_quadratic( self.b * m, self.d + (self.e * m), self.f)
        elif self.b == 0:      
            x_prime = - ( self.f ) / (self.e * m + self.d)
        else:
            raise Exception('UtilityError :: Invalid conic')

        assert x_prime > 0, 'UtilityError :: Invalid x'

        return self.identity_util / x_prime * x
    
    def get_y(self, x, util):

        x_prime = x / util * self.identity_util
        assert x_prime > 0, 'UtilityError :: Invalid x'

        y_prime = 0

        if self.c == 0:
            y_prime = -( (self.a * ( x_prime ** 2 ) ) + (self.d * x_prime) + self.f ) / ( (self.b * x_prime) + self.e )
        else:
            y_prime = self.solve_quadratic(
                                            self.c, 
                                            ( self.b * x_prime ) + self.e, 
                                            ( self.a * ( x_prime ** 2 ) ) + ( self.d * x_prime ) + self.f
                                        )
        
        assert y_prime > 0, 'UtilityError :: Invalid y'
        m = y_prime / x_prime
        return m * x
    
    def get_x(self, y, util):

        y_prime = y / util * self.identity_util
        assert y_prime > 0, 'UtilityError :: Invalid y'

        x_prime = 0

        if self.a == 0:
            x_prime = -( (self.c * ( y_prime ** 2 ) ) + (self.e * y_prime) + self.f ) / ( (self.b * y_prime) + self.d )
        else:
            x_prime = self.solve_quadratic(
                                            self.a, 
                                            ( self.b * y_prime ) + self.d, 
                                            ( self.c * ( y_prime ** 2 ) ) + ( self.e * y_prime ) + self.f
                                        )
        
        assert x_prime > 0, 'UtilityError :: Invalid x'
        m = x_prime / y_prime
        return m * y

class Pool:

    def __init__(self,curve, x_fee, y_fee, x_bal, y_bal):
        self.x = 0
        self.y = 1
        self.curve = curve
        self.x_fee = Decimal(x_fee)
        self.y_fee = Decimal(y_fee)
        self.x_bal = Decimal(x_bal)
        self.y_bal = Decimal(y_bal)
        self.total_supply = self.x_bal + self.y_bal
    
    def deposit(self, amount, token):

        amount = Decimal(amount)

        x_deposit = Decimal('0')
        y_deposit = Decimal('0')

        if(token == self.x): x_deposit = amount
        else: y_deposit = amount

        current_util = self.curve.get_utility(self.x_bal, self.y_bal)
        new_util = self.curve.get_utility(self.x_bal + x_deposit, self.y_bal + y_deposit)

        mint_amt = (new_util / current_util - 1) * self.total_supply

        self.total_supply += mint_amt
        self.x_bal += x_deposit
        self.y_bal += y_deposit

        return mint_amt
    
    def withdraw(self, amount, token):

        amount = Decimal(amount)

        current_util = self.curve.get_utility(self.x_bal, self.y_bal)
        new_util = (1 - (amount / self.total_supply)) * current_util

        self.total_supply -= amount

        if(token == self.x):

            new_x_bal = self.curve.get_x(self.y_bal, new_util)
            if self.x_bal.quantize(truncateTo) < new_x_bal.quantize(truncateTo): raise Exception('Withdraw amount exceeds maximum')
            withdraw_amt = (self.x_bal - new_x_bal) * (1 - self.x_fee)

            self.x_bal -= withdraw_amt
            
        else:

            new_y_bal = self.curve.get_y(self.x_bal, new_util)
            if self.y_bal.quantize(truncateTo) < new_y_bal.quantize(truncateTo): raise Exception('Withdraw amount exceeds maximum')
            withdraw_amt = (self.y_bal - new_y_bal) * (1 - self.y_fee)
            
            self.y_bal -= withdraw_amt

        return withdraw_amt

    def swap(self, amount, token):

        amount = Decimal(amount)

        util = self.curve.get_utility(self.x_bal, self.y_bal)

        if(token == self.x):

            new_y_bal = self.curve.get_y(self.x_bal + amount, util)
            
            if self.y_bal.quantize(truncateTo) < new_y_bal.quantize(truncateTo): raise Exception('Swap amount exceeds maximum')
            output_amt = (self.y_bal - new_y_bal) * (1 - self.y_fee)

            self.x_bal += amount
            self.y_bal -= output_amt
            
        else:

            new_x_bal = self.curve.get_x(self.y_bal + amount, util)
            
            if self.x_bal.quantize(truncateTo) < new_x_bal.quantize(truncateTo): raise Exception('Swap amount exceeds maximum')
            output_amt = (self.x_bal - new_x_bal) * (1 - self.x_fee)

            self.y_bal += amount
            self.x_bal -= output_amt
        
        return output_amt
    
    def print_balances(self):
        x_bal = self.x_bal.quantize(truncateTo)
        y_bal = self.y_bal.quantize(truncateTo)
        total_supply = self.total_supply.quantize(truncateTo)
        print(x_bal, 'X') 
        print(y_bal, 'Y') 
        print(total_supply, 'LP tokens')
        print()

if __name__ == '__main__':

    curve_params = [
        0.7129785111362054, 
        1.4023717661989632, 
        0.7129785111362054, 
        -30408.265249329583, 
        -30408.265249329583, 
        324200000
    ]

    proteus = Proteus(curve_params)
    pool = Pool(proteus, 0, 0, 1000, 1000)

    print('Current balances')
    pool.print_balances()

    pool.swap(100, 0)
    # pool.withdraw(100, 1)
    # pool.deposit(100, 0)

    print('New balances')
    pool.print_balances()