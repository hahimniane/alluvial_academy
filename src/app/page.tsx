'use client';

import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  GraduationCap, 
  Users, 
  BookOpen, 
  Award, 
  Star, 
  ArrowRight,
  Phone,
  Mail,
  MapPin 
} from 'lucide-react';

interface LandingPageContent {
  hero: {
    title: string;
    subtitle: string;
    buttonText: string;
    backgroundImage: string;
  };
  features: {
    title: string;
    subtitle: string;
    items: Array<{
      title: string;
      description: string;
      icon: string;
    }>;
  };
  stats: {
    title: string;
    items: Array<{
      number: string;
      label: string;
      icon: string;
    }>;
  };
  courses: {
    title: string;
    subtitle: string;
    items: Array<{
      title: string;
      description: string;
      duration: string;
      level: string;
      image: string;
    }>;
  };
  testimonials: {
    title: string;
    items: Array<{
      name: string;
      role: string;
      content: string;
      rating: number;
      image: string;
    }>;
  };
  cta: {
    title: string;
    subtitle: string;
    buttonText: string;
  };
  footer: {
    description: string;
    contact: {
      phone: string;
      email: string;
      address: string;
    };
    quickLinks: string[];
    socialLinks: Array<{
      platform: string;
      url: string;
    }>;
  };
}

const defaultContent: LandingPageContent = {
  hero: {
    title: "Alluwal Education Hub",
    subtitle: "Excellence in Islamic Education & Modern Learning",
    buttonText: "Explore Our Programs",
    backgroundImage: "/hero-bg.jpg"
  },
  features: {
    title: "Why Choose Alluwal Education Hub?",
    subtitle: "Comprehensive education combining traditional Islamic values with modern teaching methods",
    items: [
      {
        title: "Expert Teachers",
        description: "Learn from qualified scholars and experienced educators",
        icon: "Users"
      },
      {
        title: "Comprehensive Curriculum",
        description: "Balanced Islamic studies and academic subjects",
        icon: "BookOpen"
      },
      {
        title: "Certified Programs",
        description: "Internationally recognized qualifications",
        icon: "Award"
      }
    ]
  },
  stats: {
    title: "Our Impact",
    items: [
      { number: "500+", label: "Students", icon: "Users" },
      { number: "50+", label: "Courses", icon: "BookOpen" },
      { number: "25+", label: "Teachers", icon: "GraduationCap" },
      { number: "15+", label: "Years Experience", icon: "Award" }
    ]
  },
  courses: {
    title: "Featured Courses",
    subtitle: "Discover our comprehensive range of Islamic and academic programs",
    items: [
      {
        title: "Quran Memorization",
        description: "Complete Hifz program with proper Tajweed",
        duration: "2-4 years",
        level: "All levels",
        image: "/course-quran.jpg"
      },
      {
        title: "Islamic Studies",
        description: "Comprehensive Islamic theology and jurisprudence",
        duration: "1 year",
        level: "Intermediate",
        image: "/course-islamic.jpg"
      },
      {
        title: "Arabic Language",
        description: "Classical and modern Arabic language skills",
        duration: "6 months",
        level: "Beginner",
        image: "/course-arabic.jpg"
      }
    ]
  },
  testimonials: {
    title: "What Our Students Say",
    items: [
      {
        name: "Fatima Al-Zahra",
        role: "Hifz Graduate",
        content: "The structured approach and caring teachers made my Quran memorization journey beautiful and meaningful.",
        rating: 5,
        image: "/testimonial-1.jpg"
      },
      {
        name: "Abdullah Rahman",
        role: "Islamic Studies Student",
        content: "The depth of knowledge and practical application of Islamic teachings here is exceptional.",
        rating: 5,
        image: "/testimonial-2.jpg"
      }
    ]
  },
  cta: {
    title: "Start Your Learning Journey Today",
    subtitle: "Join our community of learners and scholars",
    buttonText: "Enroll Now"
  },
  footer: {
    description: "Alluwal Education Hub is dedicated to providing quality Islamic education while preparing students for success in this world and the hereafter.",
    contact: {
      phone: "+1 (555) 123-4567",
      email: "info@alluwaleducation.com",
      address: "123 Education Street, Learning City, LC 12345"
    },
    quickLinks: ["About Us", "Courses", "Admissions", "Contact", "Student Portal"],
    socialLinks: [
      { platform: "Facebook", url: "#" },
      { platform: "Twitter", url: "#" },
      { platform: "Instagram", url: "#" }
    ]
  }
};

export default function HomePage() {
  const [content, setContent] = useState<LandingPageContent>(defaultContent);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchContent = async () => {
      try {
        // Replace with your actual Firebase Cloud Function URL
        const response = await axios.get('https://us-central1-alluwal-academy.cloudfunctions.net/getLandingPageContent');
        setContent(response.data);
      } catch (error) {
        console.error('Error fetching content:', error);
        // Use default content if fetch fails
      } finally {
        setIsLoading(false);
      }
    };

    fetchContent();
  }, []);

  const getIcon = (iconName: string) => {
    switch (iconName) {
      case 'Users': return <Users className="w-8 h-8" />;
      case 'BookOpen': return <BookOpen className="w-8 h-8" />;
      case 'Award': return <Award className="w-8 h-8" />;
      case 'GraduationCap': return <GraduationCap className="w-8 h-8" />;
      default: return <Star className="w-8 h-8" />;
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white">
      {/* Hero Section */}
      <section className="relative bg-gradient-to-br from-emerald-600 to-teal-700 text-white py-20">
        <div className="absolute inset-0 bg-black opacity-20"></div>
        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center">
            <h1 className="text-4xl md:text-6xl font-bold mb-6">
              {content.hero.title}
            </h1>
            <p className="text-xl md:text-2xl mb-8 max-w-3xl mx-auto">
              {content.hero.subtitle}
            </p>
            <button className="bg-white text-emerald-600 px-8 py-4 rounded-lg font-semibold text-lg hover:bg-gray-100 transition-colors duration-300 inline-flex items-center gap-2">
              {content.hero.buttonText}
              <ArrowRight className="w-5 h-5" />
            </button>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mb-4">
              {content.features.title}
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              {content.features.subtitle}
            </p>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {content.features.items.map((feature, index) => (
              <div key={index} className="bg-white rounded-xl p-8 shadow-lg hover:shadow-xl transition-shadow duration-300">
                <div className="text-emerald-600 mb-4">
                  {getIcon(feature.icon)}
                </div>
                <h3 className="text-xl font-semibold text-gray-900 mb-3">
                  {feature.title}
                </h3>
                <p className="text-gray-600">
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="py-20 bg-emerald-600 text-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl md:text-4xl font-bold text-center mb-16">
            {content.stats.title}
          </h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
            {content.stats.items.map((stat, index) => (
              <div key={index} className="text-center">
                <div className="mb-4 flex justify-center">
                  {getIcon(stat.icon)}
                </div>
                <div className="text-3xl md:text-4xl font-bold mb-2">
                  {stat.number}
                </div>
                <div className="text-emerald-100">
                  {stat.label}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Courses Section */}
      <section className="py-20 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mb-4">
              {content.courses.title}
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              {content.courses.subtitle}
            </p>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {content.courses.items.map((course, index) => (
              <div key={index} className="bg-gray-50 rounded-xl overflow-hidden shadow-lg hover:shadow-xl transition-shadow duration-300">
                <div className="h-48 bg-gradient-to-br from-emerald-400 to-teal-500"></div>
                <div className="p-6">
                  <h3 className="text-xl font-semibold text-gray-900 mb-3">
                    {course.title}
                  </h3>
                  <p className="text-gray-600 mb-4">
                    {course.description}
                  </p>
                  <div className="flex justify-between text-sm text-gray-500 mb-4">
                    <span>Duration: {course.duration}</span>
                    <span>Level: {course.level}</span>
                  </div>
                  <button className="w-full bg-emerald-600 text-white py-2 rounded-lg hover:bg-emerald-700 transition-colors duration-300">
                    Learn More
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials Section */}
      <section className="py-20 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl md:text-4xl font-bold text-center text-gray-900 mb-16">
            {content.testimonials.title}
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {content.testimonials.items.map((testimonial, index) => (
              <div key={index} className="bg-white rounded-xl p-8 shadow-lg">
                <div className="flex items-center mb-4">
                  {[...Array(testimonial.rating)].map((_, i) => (
                    <Star key={i} className="w-5 h-5 text-yellow-400 fill-current" />
                  ))}
                </div>
                <p className="text-gray-600 mb-6 italic">
                  "{testimonial.content}"
                </p>
                <div className="flex items-center">
                  <div className="w-12 h-12 bg-emerald-100 rounded-full flex items-center justify-center mr-4">
                    <Users className="w-6 h-6 text-emerald-600" />
                  </div>
                  <div>
                    <div className="font-semibold text-gray-900">
                      {testimonial.name}
                    </div>
                    <div className="text-gray-500 text-sm">
                      {testimonial.role}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 bg-gradient-to-r from-emerald-600 to-teal-600 text-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl md:text-4xl font-bold mb-4">
            {content.cta.title}
          </h2>
          <p className="text-xl mb-8">
            {content.cta.subtitle}
          </p>
          <button className="bg-white text-emerald-600 px-8 py-4 rounded-lg font-semibold text-lg hover:bg-gray-100 transition-colors duration-300 inline-flex items-center gap-2">
            {content.cta.buttonText}
            <ArrowRight className="w-5 h-5" />
          </button>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-white py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
            <div className="md:col-span-2">
              <h3 className="text-xl font-bold mb-4">Alluwal Education Hub</h3>
              <p className="text-gray-300 mb-6">
                {content.footer.description}
              </p>
              <div className="space-y-2">
                <div className="flex items-center gap-3">
                  <Phone className="w-5 h-5 text-emerald-400" />
                  <span>{content.footer.contact.phone}</span>
                </div>
                <div className="flex items-center gap-3">
                  <Mail className="w-5 h-5 text-emerald-400" />
                  <span>{content.footer.contact.email}</span>
                </div>
                <div className="flex items-center gap-3">
                  <MapPin className="w-5 h-5 text-emerald-400" />
                  <span>{content.footer.contact.address}</span>
                </div>
              </div>
            </div>
            <div>
              <h4 className="text-lg font-semibold mb-4">Quick Links</h4>
              <ul className="space-y-2">
                {content.footer.quickLinks.map((link, index) => (
                  <li key={index}>
                    <a href="#" className="text-gray-300 hover:text-emerald-400 transition-colors duration-300">
                      {link}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h4 className="text-lg font-semibold mb-4">Follow Us</h4>
              <div className="space-y-2">
                {content.footer.socialLinks.map((social, index) => (
                  <a
                    key={index}
                    href={social.url}
                    className="block text-gray-300 hover:text-emerald-400 transition-colors duration-300"
                  >
                    {social.platform}
                  </a>
                ))}
              </div>
            </div>
          </div>
          <div className="border-t border-gray-800 mt-12 pt-8 text-center text-gray-400">
            <p>&copy; 2024 Alluwal Education Hub. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
  );
} 