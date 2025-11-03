import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

function App() {
  const [options, setOptions] = useState([]);
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');

  useEffect(() => {
    loadOptions();
    loadResults();
  }, []);

  const loadOptions = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/options`);
      setOptions(response.data);
      setLoading(false);
    } catch (error) {
      console.error('Erreur chargement options:', error);
      setLoading(false);
    }
  };

  const loadResults = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/results`);
      setResults(response.data);
    } catch (error) {
      console.error('Erreur chargement résultats:', error);
    }
  };

  const handleVote = async (optionId) => {
    try {
      await axios.post(`${API_URL}/api/vote`, { option_id: optionId });
      setMessage('Vote enregistré avec succès !');
      loadResults();
      setTimeout(() => setMessage(''), 3000);
    } catch (error) {
      setMessage('Erreur lors du vote');
      console.error('Erreur vote:', error);
    }
  };

  const handleReset = async () => {
    if (window.confirm('Réinitialiser tous les votes ?')) {
      try {
        await axios.post(`${API_URL}/api/reset`);
        setMessage('Votes réinitialisés !');
        loadResults();
        setTimeout(() => setMessage(''), 3000);
      } catch (error) {
        setMessage('Erreur lors de la réinitialisation');
        console.error('Erreur reset:', error);
      }
    }
  };

  if (loading) {
    return <div className="App"><h2>Chargement...</h2></div>;
  }

  const totalVotes = results.reduce((sum, r) => sum + r.votes, 0);

  return (
    <div className="App">
      <header className="App-header">
        <h1>🗳️ SecureVote</h1>
        <p>Votez pour votre technologie de conteneurisation préférée</p>
      </header>

      {message && <div className="message">{message}</div>}

      <div className="container">
        <section className="vote-section">
          <h2>Options de vote</h2>
          <div className="options">
            {options.map((option) => (
              <div key={option.id} className="option-card">
                <h3>{option.name}</h3>
                <p>{option.description}</p>
                <button onClick={() => handleVote(option.id)}>
                  Voter
                </button>
              </div>
            ))}
          </div>
        </section>

        <section className="results-section">
          <h2>Résultats en temps réel</h2>
          <p>Total : {totalVotes} votes</p>
          <div className="results">
            {results.map((result) => {
              const percentage = totalVotes > 0
                ? ((result.votes / totalVotes) * 100).toFixed(1)
                : 0;
              return (
                <div key={result.name} className="result-item">
                  <div className="result-label">
                    <span>{result.name}</span>
                    <span>{result.votes} votes ({percentage}%)</span>
                  </div>
                  <div className="result-bar">
                    <div
                      className="result-fill"
                      style={{ width: `${percentage}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
          <button className="reset-btn" onClick={handleReset}>
            Réinitialiser les votes
          </button>
        </section>
      </div>

      <footer>
        <p>Projet fil rouge - Sécurité et Production Docker</p>
      </footer>
    </div>
  );
}

export default App;
