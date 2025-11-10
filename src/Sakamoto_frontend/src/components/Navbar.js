import React from 'react';

function Navbar() {
  return (
    <nav className="bg-gray-800 p-4 text-white shadow-lg">
      <div className="container mx-auto flex justify-between items-center">
        <a href="/" className="text-xl font-bold">Sakamoto Dapp</a>
        <ul className="flex space-x-4">
          <li><a href="/staking" className="hover:text-gray-300">Staking</a></li>
          <li><a href="/profile" className="hover:text-gray-300">Profile</a></li>
          <li><a href="/auth" className="hover:text-gray-300">Login</a></li>
        </ul>
      </div>
    </nav>
  );
}

export default Navbar;
