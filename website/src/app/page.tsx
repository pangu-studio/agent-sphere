import NavBar from "@/components/sections/NavBar";
import HeroSection from "@/components/sections/HeroSection";
import FeaturesSection from "@/components/sections/FeaturesSection";
import InstallSection from "@/components/sections/InstallSection";
import HowItWorks from "@/components/sections/HowItWorks";
import FooterSection from "@/components/sections/FooterSection";

export default function Home() {
  return (
    <>
      <NavBar />
      <main className="flex-1">
        <HeroSection />
        <FeaturesSection />
        <InstallSection />
        <HowItWorks />
      </main>
      <FooterSection />
    </>
  );
}
