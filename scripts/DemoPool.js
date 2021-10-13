async function deployPool(curveParams){
    const poolContract = await ethers.getContractFactory("DemoPool");
    const abdkScale = ethers.BigNumber.from("0x10000000000000000");
    const deployParams = [];                                    
    for(let i = 0; i < curveParams.length; i++){
        deployParams.push(ethers.utils.parseEther(curveParams[i].toString()).mul(abdkScale).div(ethers.utils.parseEther('1')));
    }
    return await poolContract.deploy(deployParams);
}

async function deposit(pool, balances, inputData){
    const xBal = ethers.utils.parseEther(balances.xBal.toString());
    const yBal = ethers.utils.parseEther(balances.yBal.toString());
    const totalSupply = ethers.utils.parseEther(balances.totalSupply.toString());
    const amount = ethers.utils.parseEther(inputData.amt.toString());

    const result = await pool.deposit(xBal, yBal, totalSupply, amount, inputData.token);
    return parseInt(result) / 1e18;
}

async function withdraw(pool, balances, inputData){
    const xBal = ethers.utils.parseEther(balances.xBal.toString());
    const yBal = ethers.utils.parseEther(balances.yBal.toString());
    const totalSupply = ethers.utils.parseEther(balances.totalSupply.toString());
    const amount = ethers.utils.parseEther(inputData.amt.toString());

    const result = await pool.withdraw(xBal, yBal, totalSupply, amount, inputData.token);
    return parseInt(result) / 1e18;
}

async function swap(pool, balances, inputData){
    const xBal = ethers.utils.parseEther(balances.xBal.toString());
    const yBal = ethers.utils.parseEther(balances.yBal.toString());
    const amount = ethers.utils.parseEther(inputData.amt.toString());

    const result = await pool.swap(xBal, yBal, amount, inputData.token);
    return parseInt(result) / 1e18;
}

async function main() {

    const curveParams = [
        0.7129785111362054, 
        1.4023717661989632, 
        0.7129785111362054, 
        -30408.265249329583, 
        -30408.265249329583, 
        324200000
    ];
    const pool = await deployPool(curveParams);

    const tokens = ['X', 'Y'];
    const balances = { xBal: 1000, yBal: 1000, totalSupply: 2000 }
    const depositData = { amt: 100, token: 0 }
    const withdrawData = { amt: 100, token: 1 }
    const swapData = { amt: 100, token: 0 }

    const depositResult = await deposit(pool, balances, depositData);
    const withdrawResult = await withdraw(pool, balances, withdrawData);
    const swapResult = await swap(pool, balances, swapData);

    console.log(`Deposit ${depositData.amt} ${tokens[depositData.token]} -> Mint ${depositResult} shells\n`);
    console.log(`Burn ${withdrawData.amt} shells -> Withdraw ${withdrawResult} ${tokens[withdrawData.token]}\n`);
    console.log(`Swap ${swapData.amt} ${tokens[swapData.token]} -> Receive ${swapResult} ${tokens[!swapData.token | 0]}\n`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
});