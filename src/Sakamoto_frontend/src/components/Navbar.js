import React from 'react';
import { Link } from 'react-router-dom';

function Navbar() {
  return (
    <nav className="bg-gray-800 p-4 text-white shadow-lg">
      <div className="container mx-auto flex justify-between items-center">
        <Link to="/" className="text-xl font-bold">Sakamoto Dapp</Link>
        <ul className="flex space-x-4">
          <li><Link to="/staking" className="hover:text-gray-300">Staking</Link></li>
          <li><Link to="/profile" className="hover:text-gray-300">Profile</Link></li>
          <li><Link to="/" className="hover:text-gray-300">Login</Link></li>
        </ul>
      </div>
    </nav>
  );
}

export default Navbar;
