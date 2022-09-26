from locale import normalize
import math

from xml.dom.minidom import AttributeList

# Define N, prices, liquidity
# Saving sqrt prices (it's all we need, save calcs later) & normalized liq (kappa)

n_slices = 7
n_rays = n_slices-1

prices = [0.9,0.99,.999,1.001,1.01,1.1]
sqrt_prices = [math.sqrt(x) for x in prices]

# Use liquidity to get normalized liquidity (uppercase Kappa)
liquidity = [0.5, 9.5, 20, 40, 20, 9, 1]
kappa = [x/min(liquidity) for x in liquidity]

# Define the slopes for each ray
m = []
for i in range(n_rays):
    numerator_sum = kappa[i] * sqrt_prices[i]
    for j in range(0,i):
        numerator_sum = numerator_sum + (sqrt_prices[j]*(kappa[j]-kappa[j+1]))
    numerator = numerator_sum
    denom = kappa[i+1]/sqrt_prices[i]
    if i < n_rays-1:
        for l in range(i+1,n_rays):
            denom = denom + ((kappa[l+1] - kappa[l])/sqrt_prices[l])

    m.append(numerator/denom)

# Calculate the 'a' and 'b' values for each segment/slice for the equation (x+a)(y+b)=1
a = []
b = []
for i in range(n_slices):
    if i == n_slices-1: a.append(0)
    else:
        a_sum = 0
        for j in range(i,n_slices-1):
            a_sum = a_sum + (kappa[j]-kappa[j+1])/sqrt_prices[j]
        a.append(a_sum/kappa[i])

    if i == 0: b.append(0)
    else:
        b_sum = 0
        for j in range(i):
            b_sum = b_sum + sqrt_prices[j]*(kappa[j+1]-kappa[j])
        b.append(b_sum/kappa[i])

# Print everything
print("=====================")
print("       DATA          ")
print("=====================")

print('N (slices) = ', n_slices)
print('n (rays) = ', n_rays)

print("=====================")
print("  PRICES AND SLOPES  ")
print("=====================")

for price in prices:
    print('ray #', prices.index(price)+1,": ", "price = ",price,"; slope = ",m[prices.index(price)])

print("=====================")
print("   CURVE EQUATIONS   ")
print("=====================")

for slice in range(n_slices):
    print("slice #", slice+1,": a = ", a[slice], "; b = ", b[slice])