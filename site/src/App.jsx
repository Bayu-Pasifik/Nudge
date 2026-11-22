import Hero from './sections/Hero.jsx';
import NagSequence from './sections/NagSequence.jsx';
import Places from './sections/Places.jsx';
import Sync from './sections/Sync.jsx';
import Control from './sections/Control.jsx';
import Cta from './sections/Cta.jsx';

export default function App() {
  return (
    <>
      <a className="skip" href="#isi">Lewati ke isi</a>
      <Hero />
      <main id="isi">
        <NagSequence />
        <Places />
        <Sync />
        <Control />
      </main>
      <Cta />
    </>
  );
}
