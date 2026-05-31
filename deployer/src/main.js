import { ethers } from "ethers";

const statusEl = document.getElementById('status');
const connectBtn = document.getElementById('connect');

let provider;
let signer;

connectBtn.addEventListener('click', async () => {
  if (!window.ethereum) {
    alert("Please install MetaMask");
    return;
  }

  provider = new ethers.BrowserProvider(window.ethereum);
  await provider.send("eth_requestAccounts", []);
  signer = await provider.getSigner();
  const address = await signer.getAddress();
  const network = await provider.getNetwork();

  statusEl.innerHTML = `
    <p><strong>Connected:</strong> ${address}</p>
    <p><strong>Chain:</strong> ${network.name} (${network.chainId})</p>
  `;

  if (network.chainId !== 8453n) {
    statusEl.innerHTML += `<p style="color:red">Please switch to Base Mainnet (8453)</p>`;
    return;
  }

  // Placeholder - real deployment logic would go here
  statusEl.innerHTML += `
    <p>Browser-based deployment of complex contracts is advanced.</p>
    <p><strong>Recommended approach right now:</strong></p>
    <ul>
      <li>Run the Hardhat Ignition command locally (safest)</li>
      <li>Or use Remix IDE in the browser for simpler deployments</li>
    </ul>
    <p>Would you like me to build a more complete local deployer dApp?</p>
  `;
});
