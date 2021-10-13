// SPDX-License-Identifier: unlicensed
// Cowri Labs, Inc.

pragma solidity ^0.8.0;

import {ABDKMath64x64 as ABDKMath} from "./ABDKMath64x64.sol";

contract DemoPool {

    using ABDKMath for int128;
    using ABDKMath for uint256;

    // ABDK Constants
    int128 internal constant ONE = 0x10000000000000000;
    int128 internal constant TWO = 0x20000000000000000;
    int128 internal constant FOUR = 0x40000000000000000;

    uint256 internal constant xTokenId = 0;
    uint256 internal constant yTokenId = 1;
    int128 internal constant xFEE = 0;
    int128 internal constant yFEE = 0;

    // Parameters of the conic section defining the bonding curve
    // Ax^2 + Bxy + Cy^2 + Dx + Ey + F = 0
    int128 public immutable a;
    int128 public immutable b;
    int128 public immutable c;
    int128 public immutable d;
    int128 public immutable e;
    int128 public immutable f;

    // We measure utility as the x-value of the intersection of the identity 
    // curve and the line y/x=1
    int128 public immutable utilityOfIdentityCurve;

    constructor(int128[6] memory params) {
        utilityOfIdentityCurve = _calculateUtilityOfIdentityCurve(params);
        a = params[0];
        b = params[1];
        c = params[2];
        d = params[3];
        e = params[4];
        f = params[5];
    }

    function deposit(
        uint256 balanceOfXToken,
        uint256 balanceOfYToken,
        uint256 totalSupplyOfLPToken,
        uint256 amountDeposited,
        uint256 idOfTokenDeposited
    ) public view returns (uint256 amountOfLPTokensMinted) {
        uint256 currentUtility = _utilityForValues(balanceOfXToken, balanceOfYToken);

        // Add the amount deposited to get the new x and y balances, which we use
        // to find the nextUtility
        uint256 nextUtility = 
            idOfTokenDeposited == xTokenId ? 
            _utilityForValues(balanceOfXToken + amountDeposited, balanceOfYToken) :
            _utilityForValues(balanceOfXToken, balanceOfYToken + amountDeposited);

        // We want to issue the user LP Tokens commensurate to the change
        // in utility that occurs as a result of their deposit.
        // %change of LP Tokens = (nextUtility / currentUtility) - 1
        // mint = totalSupply * %change
        amountOfLPTokensMinted = nextUtility.divu(currentUtility).sub(ONE).mulu(totalSupplyOfLPToken);
    }

    function withdraw(
        uint256 balanceOfXToken,
        uint256 balanceOfYToken,
        uint256 totalSupplyOfLPToken,
        uint256 amountOfLPTokensBurned,
        uint256 idOfTokenWithdrawn
    ) public view returns (uint256 amountWithdrawn) {
        uint256 currentUtility = _utilityForValues(balanceOfXToken, balanceOfYToken);

        // The next utility is commensurate to the percentage of LP Tokens
        // being burned for this withdrawal.
        // nextUtility = (1 - (% of LP Tokens burned) ) * currentUtility
        uint256 nextUtility = 
            ONE.sub((amountOfLPTokensBurned.divu(totalSupplyOfLPToken))).mulu(currentUtility);

        // We are withdrawing into one token, so the balance of the other token
        // does not change.
        // The utility uniquely identifies our bonding curve at a certain scale.
        // Since the curve defines a bijective mapping between x and y, we can 
        // compute the next balance of one token given the unchanging balance 
        // of the other token and the next utility.
        // Subtract the next balance from the current balance, less the fee,
        // to get the amount withdrawn.
        if (idOfTokenWithdrawn == xTokenId) {
            uint256 nextXBalance = _xForYAndUtil(balanceOfYToken, nextUtility);
            require(nextXBalance <= balanceOfXToken, "WithdrawError :: Constraint violation");
            amountWithdrawn = ONE.sub(xFEE).mulu(balanceOfXToken - nextXBalance);
        } else {
            uint256 nextYBalance = _yForXAndUtil(balanceOfXToken, nextUtility);
            require(nextYBalance <= balanceOfYToken, "WithdrawError :: Constraint violation");
            amountWithdrawn = ONE.sub(yFEE).mulu(balanceOfYToken - nextYBalance);
        }
    }

    function swap(
        uint256 balanceOfXToken,
        uint256 balanceOfYToken,
        uint256 inputAmount,
        uint256 idOfInputToken
    ) public view returns (uint256 outputAmount) {
        uint256 utility = _utilityForValues(balanceOfXToken, balanceOfYToken);

        // The definition of a swap is moving to a different point on the same
        // curve.  Holding utility invariant, we increase the balance of the input
        // token to compute the next balance of the output token.
        // We then subtract the next balance from the current balance, less the fee,
        // to get the output amount.
        if (idOfInputToken == xTokenId) {
            uint256 nextYBalance = _yForXAndUtil(balanceOfXToken + inputAmount, utility);
            require(balanceOfYToken >= nextYBalance, "SwapError :: Constraint violation");
            outputAmount = (ONE.sub(yFEE)).mulu(balanceOfYToken - nextYBalance);
        } else {
            uint256 nextXBalance = _xForYAndUtil(balanceOfYToken + inputAmount, utility);
            require(balanceOfXToken >= nextXBalance, "SwapError :: Constraint violation");
            outputAmount = (ONE.sub(xFEE)).mulu(balanceOfXToken - nextXBalance);
        }
    }

    function _calculateUtilityOfIdentityCurve(int128[6] memory params) internal pure returns (int128 _utilityOfIdentityCurve) {
        int128 _a = params[0];
        int128 _b = params[1];
        int128 _c = params[2];
        int128 _d = params[3];
        int128 _e = params[4];
        int128 _f = params[5];

        // since we want the point where the curve intersects the line y = x,
        // we substitute y = x, which gives us Ax^2 + Bx^2 + Cx^2 + Dx + Ex + F = 0
        // Simplify to (a + b + c)x^2 + (d + e)x + f and solve for the smallest root.
        int128 ax2 = _a.add(_b).add(_c);
        int128 bx = _d.add(_e);
        if (ax2 != 0) {
            _utilityOfIdentityCurve = _smallestPositiveRootOfQuadratic(ax2, bx, _f);
        } 
        else {
            _utilityOfIdentityCurve = _f.div(bx).neg();
        }
        require(_utilityOfIdentityCurve > 0, "Curve does not intersect y = x in Q1");
    }

    function _utilityForValues(uint256 x, uint256 y) internal view returns (uint256) {
        // slope of the line that goes from the origin to our current balances
        int128 m = y.divu(x);
        // given m=y/x, we want to compute x', the the projection of the current balance of x
        // onto the identity curve.
        int128 xPrime; 
        
        // since we want to find the point on the identity curve that the line y = mx
        // passes through, we substitute y = mx, which gives us
        // A * x^(2) + B * m * x^(2) + C * m^(2) * x^(2) + D * x + E * m * x + F = 0
        // This simplifies to (A + Bm + Cm^2)x^2 + (D + Em)x + F = 0
        if (a + b + c != 0) { // All conics except constant product and constant sums
            xPrime = _smallestPositiveRootOfQuadratic(
                a.add(b.mul(m)).add(c.mul(m.pow(2))), 
                d.add(e.mul(m)),
                f
            );
        } else if (b != 0) { // constant product conic
            // b*m
            // d + e*m
            // f
            xPrime = _smallestPositiveRootOfQuadratic(
                b.mul(m),
                d.add(e.mul(m)),
                f
            );
        } else if (b == 0) { // constant sum conic
            // -f / (e*m + d)
            xPrime =  f.div(e.mul(m).add(d)).neg();
        } 
        else {
            revert("UtilityError :: Invalid conic");
        }
        require(xPrime > 0, "UtilityError :: Invalid x'");

        // Compute λ, which is the linear scale factor between the current 
        // x and the projection of x onto the identity curve (x')
        // λ = x / x'
        // use λ to compute utility of the current curve
        // utility = λ * utilityOfIdentityCurve
        // Reordering these operations:
        // utility = utilityOfIdentityCurve / x' * x
        return utilityOfIdentityCurve.div(xPrime).mulu(x);

    }

    function _yForXAndUtil(uint256 balanceOfX, uint256 currentUtility) internal view returns (uint256 balanceOfY) {
        // Compute λ, which is the linear scale factor between the current 
        // utility and the utility of the identity curve
        // λ =  utility / utilityOfIdentityCurve
        // use λ to compute x', which is the projection of the current balance of x
        // onto the identity curve.
        // x' = balanceOfX / λ 
        // Reordering these operations:
        // x' = balanceOfX / utility * utilityOfIdentityCurve
        int128 xPrime = balanceOfX.divu(currentUtility).mul(utilityOfIdentityCurve);
        require(xPrime > 0, "UtilityError :: Invalid x'"); 

        // we're now computing y', which we will use to find y
        int128 yPrime;

        if (c == 0) { // Constant product or constant sum
            // - ( ( (a * x^2) + (d * x) + f) ) / ( (b * x) + e ) 
            yPrime = (
                (a.mul(xPrime.pow(2))
                    .add(d.mul(xPrime))
                    .add(f)
                ).div(
                    b.mul(xPrime)
                        .add(e)
                )
            ).neg();
        } else { // Other conics
            // c
            // b * x + e
            // a * x^2 + d * x + f
            yPrime = _smallestPositiveRootOfQuadratic(
                c,
                b.mul(xPrime)
                    .add(e),
                a.mul(xPrime.pow(2))
                    .add(d.mul(xPrime))
                    .add(f)
            );
        }
        require(yPrime > 0, "UtilityError :: invalid y'");

        // y' = mx',  y = mx
        // Now that we have y' and x', we can calculate m
        // m = y' / x'
        int128 m = yPrime.div(xPrime);
        // we can now calculate y given x and m.
        balanceOfY =  m.mulu(balanceOfX);
    }

    function _xForYAndUtil(uint256 balanceOfY, uint256 currentUtility) internal view returns(uint256 balanceOfX) {
        // Compute λ, which is the linear scale factor between the current 
        // utility and the utility of the identity curve
        // λ = utility / utilityOfIdentityCurve
        // use λ to compute y', which is the projection of the current balance of y
        // onto the identity curve.
        // y' = balanceOfY / λ
        // Reordering these operations:
        // y' = balanceOfY / utility * utilityOfIdentityCurve
        int128 yPrime = balanceOfY.divu(currentUtility).mul(utilityOfIdentityCurve);
        require(yPrime > 0, "UtilityError :: Invalid y'");

        // we're now computing x', which we will use to find x
        int128 xPrime;

        if (a == 0) { // Constant product or constant sum
            // - ( ( (c * y^2) + (e * y) + f) ) / ( (b * y) + d ) 
            xPrime = (
                (c.mul(yPrime.pow(2))
                    .add(e.mul(yPrime))
                    .add(f)
                ).div(
                    b.mul(yPrime)
                        .add(d)
                )
            ).neg();
        } else { // Other conics
            // a
            // b * y + d
            // c * y^2 + e * y + f
            xPrime = _smallestPositiveRootOfQuadratic(
                a,
                b.mul(yPrime)
                    .add(d),
                c.mul(yPrime.pow(2))
                    .add(e.mul(yPrime))
                    .add(f)
            );
        }
        require(xPrime > 0, "UtilityError :: x'");

        // x' = my',  x = my
        // m = x' / 'y
        // Now that we have y' and x', we can calculate m
        int128 m = xPrime.div(yPrime);
        // we can now calculate x given y and m.
        balanceOfX = m.mulu(balanceOfY);
    }

    function _smallestPositiveRootOfQuadratic(int128 _a, int128 _b, int128 _c) internal pure returns(int128 solution) {
        // (-b +- sqrt(b^2 - 4ac)) / (2a)
        // discriminant is the term under the square root
        int128 discriminant = _b.pow(2).sub(FOUR.mul(_a).mul(_c));
        require(discriminant >= 0, "QuadraticError :: No real roots");
        int128 sqrtDiscriminant = discriminant.sqrt();

        // denominator = 2a
        int128 denominator = _a.mul(TWO);

        // Reorder -b +- sqrtDiscriminant as:
        // [ sqrtDiscriminant - b ] and [ -(sqrtDiscriminant + b) ]
        // divide each by the denominator.
        int128 root1 = (sqrtDiscriminant.sub(_b)).div(denominator);
        int128 root2 = (_b.add(sqrtDiscriminant)).div(denominator).neg();

        if (0 < root1 && root1 < root2) {        // <---0---(r1)---r2--->
            solution =  root1;
        } else if (0 < root2 && root2 < root1) { // <---0---(r2)---r1--->
            solution =  root2;
        } else if (0 < root1 && root2 < 0) {     // <---r2---0---(r1)--->
            solution =  root1;
        } else if (root1 < 0 && 0 < root2) {     // <---r1---0---(r2)--->
            solution =  root2;
        } else {
            revert("QuadraticError :: No positive root");
        }
    }
}
