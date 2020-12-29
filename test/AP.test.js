const chai  = require("chai");
const {assert, expect} = chai;

const REDEMPTION_POOL_SIZE = ethers.BigNumber.from("100000000");

describe("AP", () => {
  let owner, worker, ap, redemption, newRedemption, farm, ownerSigner;
  let APRedemption, HarvestAP, TestERC20, TestAPUpgrade;

  function expectErr (e, msg) {
    expect(e.message).to.include(msg);
  }

  before("deploy", async () => {
    accounts = await ethers.getSigners();
    ownerSigner = accounts[0];
    owner = await ownerSigner.getAddress();

    [APRedemption, HarvestAP, TestERC20, TestAPUpgrade] = await Promise.all([
      ethers.getContractFactory("APRedemption", ownerSigner),
      ethers.getContractFactory("HarvestAP", ownerSigner),
      ethers.getContractFactory("TestERC20", ownerSigner),
      ethers.getContractFactory("TestAPUpgrade", ownerSigner),
    ]);

    farm = await TestERC20.deploy("", "", 0);
    await farm.deployed();

    ap = await HarvestAP.deploy(owner, farm.address);
    await ap.deployed();

    let redemptionAddress = await ap.redemption();
    redemption = await APRedemption.attach(redemptionAddress);

    newRedemption = await TestAPUpgrade.deploy(farm.address, ap.address);
    await newRedemption.deployed()

    let tx = await farm.setBalance(redemption.address, REDEMPTION_POOL_SIZE);
    await tx.wait();
  });

  it('should block direct redeem calls', async () => {
    try {
      await ap.callStatic.redeem(owner, 100);
    } catch (e) {
      expectErr(e, "HarvestAP/redeem - This function may only be called by APRedemption");
    }
  });


  it('should allow redemption', async () => {
    // give owner 50% of total AP
    const [tx1, tx2] = await Promise.all([
      ap.mint(owner, 100),
      ap.mint("0x" + "22".repeat(20), 100), // half to junk address
    ]);
    await Promise.all([
      tx1.wait(),
      tx2.wait(),
    ]);

    // redeem 50% of holdings. Should receive 25% of farm
    let tx = await redemption.redeem(50);
    await tx.wait();

    // Check balances
    let farmBalance = await farm.balanceOf(owner);
    let expected = REDEMPTION_POOL_SIZE.div(4);
    assert(farmBalance.eq(expected));

    let apBalance = await ap.balanceOf(owner);
    assert(apBalance.eq(50));
  });


  describe('replace redemption', () => {
    it('should allow redemption at new contract', async () => {
      let farmToMigrate = await farm.balanceOf(redemption.address);

      let tx = await ap.setRedemption(newRedemption.address);
      await tx.wait();

      // check FARM was moved
      let oldRedFarm = await farm.balanceOf(redemption.address);
      assert(oldRedFarm.isZero());
      let newRedFarm = await farm.balanceOf(newRedemption.address);
      assert(newRedFarm.eq(farmToMigrate));

      // relies on previous tests(!)
      // redeem remainder holdings. 
      tx = await newRedemption.redeem(50);
      await tx.wait();

      // Should now have 50% of initial farm pool
      let farmBalance = await farm.balanceOf(owner);
      let expected = REDEMPTION_POOL_SIZE.div(2);
      assert(farmBalance.eq(expected));

      let apBalance = await ap.balanceOf(owner);
      assert(apBalance.isZero());
    });

    it('should fail at old contract', async () => {
      // we expect owner to have no AP now
      let tx = await ap.mint(owner, 5);
      await tx.wait();

      try {
        tx = await redemption.redeem(5);
      } catch (e) {
        expectErr(e, "HarvestAP/redeem - This function may only be called by APRedemption");
      }
    });
  });
});
