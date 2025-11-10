import React from 'react';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import AuthPage from './pages/AuthPage';
import StakingPage from './pages/StakingPage';
import ProfilePage from './pages/ProfilePage';

function App() {
  return (
    <div className="min-h-screen bg-gray-100 flex flex-col">
      <Navbar />
      <main className="flex-grow container mx-auto p-4">
        <AuthPage />
        <StakingPage />
        <ProfilePage />
      </main>
      <Footer />
    </div>
  );
}

export default App;
