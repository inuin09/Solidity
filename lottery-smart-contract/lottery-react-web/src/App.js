import logo from './logo.svg';
import './App.css';
import Web3 from 'web3';

function App() {
  async componentDidMount(){
    await this.initWeb3
  }

  return new Promise((resolve, reject) => {
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <p>
          Edit <code>src/App.js</code> and save to reload.
        </p>
        <a
          className="App-link"
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn React
        </a>
      </header>
    </div>

    //web3랑 메타마스크랑 연동하기
    // 1
     window.addEventListener('load', async () => {
       let web3, account;
       // 2
       if (window.ethereum) {
         web3 = new Web3(window.ethereum);
       // 3
       } else if (typeof window.web3 !== 'undefined') {
         web3 = new Web3(window.web3.currentProvider);
       } else {
         // 4
         reject(new Error('No web3 instance injected, using local web3.'))
       }
       if (web3) {
         // 5
         account = await web3.eth.requestAccounts();
       }
     })
   })
  // return (
  //   <div className="App">
  //     <header className="App-header">
  //       <img src={logo} className="App-logo" alt="logo" />
  //       <p>
  //         Edit <code>src/App.js</code> and save to reload.
  //       </p>
  //       <a
  //         className="App-link"
  //         href="https://reactjs.org"
  //         target="_blank"
  //         rel="noopener noreferrer"
  //       >
  //         Learn React
  //       </a>
  //     </header>
  //   </div>
  // );
}

export default App;
